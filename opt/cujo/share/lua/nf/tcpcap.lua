--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- Standard luacheck globals stanza based on what NFLua preloads and
-- the order in which cujo.nf loads these scripts.
--
-- luacheck: read globals config data
-- luacheck: read globals base64 json timer
-- luacheck: read globals debug debug_logging
-- luacheck: read globals lru
-- luacheck: read globals nf
-- luacheck: read globals threat
-- luacheck: read globals conn
-- luacheck: read globals safebro
-- luacheck: read globals ssl
-- luacheck: read globals http
-- (caps exports no globals)
-- (tcptracker exports no globals)
-- (apptracker exports no globals)
-- luacheck: read globals p0f_httpsig p0f_tcpsig
-- (httpcap exports no globals)
-- (tcpcap exports no globals)
-- luacheck: read globals appblocker
-- luacheck: read globals gquic
-- luacheck: read globals dns
-- (ssdpcap exports no globals)

-- Fingerprinting devices based on TCP SYN packets.

local config = {
    tcp_hdrlen = 20,
    ipv4_hdrlen = 20,
    ipv6_hdrlen = 40,
    mtu = 1500,
    max_dist = 35,
    ipv4_df = 0x02,
    ipv6_ecn = 0x03,
}

-- tcp optional header info
local options = {
    [0] = 'eol',
    [1] = 'nop',
    [2] = 'mss',
    [3] = 'ws',
    [4] = 'sok',
    [5] = 'sack',
    [8] = 'ts',
}

local next_option = data.layout{
    kind = { 0, 8},
    len = { 8, 8},
    mss = { 16, 16, 'net'},
    ws = { 16, 8},
    ts = { 16, 32, 'net'},
}

local function get_tcp_options(tcp)
    
    local option = tcp:segment(config.tcp_hdrlen)
    local options_len = (tcp.doff * 4) - config.tcp_hdrlen

    local found = {}
    local tcp_options = {mss = 0, ws = 0}

    local len, opt
    while options_len > 0 and option do
        option:layout(next_option)
        opt = options[option.kind]

        if opt == 'eol' then
            found[#found + 1] = 'eol+' .. (options_len - 1)
            break
        end

        found[#found + 1] = opt or '?' .. option.kind
        if opt == 'nop' then
            len = 1
        else
            len = option.len
            if opt and option[opt] then
                tcp_options[opt] = option[opt]
            end
        end
        option = option:segment(len)
        options_len = options_len - len
    end

    tcp_options.found = found
    return tcp_options
end

-- detect if window size is a multiple of mss or mtu (the way p0f does it...)
local function detect_multi(ip, tcp, tcp_options, syn_mss)

    local mss = tcp_options.mss
    local win = tcp.window

    if win == 0 or mss < 100 then
        return win
    end
    if (win % mss) == 0 then
        return 'mss*' .. (win//mss)
    end

    -- some systems sometimes subtract 12 bytes when timestamps are in use
    local div = mss - 12
    if tcp_options.ts and (win % div) == 0 then
        return 'mss*'..(win//div)
    end

    -- some systems use MTU on the wrong interface
    -- check for most common case
    local min_tcp, ip_hdr
    if ip.version == 6 then
        min_tcp = config.ipv6_hdrlen + config.tcp_hdrlen
        ip_hdr = config.ipv6_hdrlen
    else
        min_tcp = config.ipv4_hdrlen + config.tcp_hdrlen
        ip_hdr = ip.ihl * 4
    end
    div = config.mtu - min_tcp
    if (win % div) == 0 then
        return 'mss*'..(win//div)
    else
        div = div - 12
        if (win % div) == 0 then
            return 'mss*'..(win//div)
        end
    end

    -- some systems use MTU instead of mss
    div = mss + min_tcp
    if (win % div) == 0 then
        return 'mtu*'..(win//div)
    end

    div = mss + ip_hdr
    if (win % div) == 0 then
        return 'mtu*'..(win//div)
    end

    if (win % config.mtu) == 0 then
        return 'mtu*'..(win//config.mtu)
    end

    return win
end

-- ip stuff in signature
local lims = {32, 64, 128, 255}

local function get_sigip(ip)
    local dist, ttl, opt_len
    if ip.version == 4 then
        ttl = ip.ttl
        opt_len = (ip.ihl * 4) - config.ipv4_hdrlen
    else
        ttl = ip.hl
        opt_len = 0 -- ipv6 extensions are part of payload
    end
    for _, lim in ipairs(lims) do
        if ttl <= lim then
            dist = lim - ttl
            break
        end
    end
    if dist > config.max_dist then dist = '?' end

    return { version = ip.version, ttl = ttl, dist = dist, opt_len = opt_len }
end

-- tcp stuff in signature
local function get_sigtcp(ip, tcp, tcp_options, syn_mss)
    local win_multi = detect_multi(ip, tcp, tcp_options, syn_mss)
    return { mss = tcp_options.mss, win = win_multi, ws = tcp_options.ws, 
    options = tcp_options.found }
end

-- quirks stuff
local function get_quirks(ip, tcp)
    local quirks = {}
    local ecn

    -- ip quirks
    if ip.version == 4 then
        if ip.ecn ~= 0 then
            quirks[#quirks + 1] = 'ecn'
            ecn = true
        end
        if (ip.flags & config.ipv4_df) ~= 0 then
            quirks[#quirks + 1] = 'df'
            if ip.id ~= 0 then
                quirks[#quirks + 1] = 'id+'
            end
        else
            if ip.id == 0 then
                quirks[#quirks + 1] = 'id-'
            end
        end
    else
        if ip.fl ~= 0 then quirks[#quirks+1] = 'flow' end
            if (ip.tc & config.ipv6_ecn ) ~= 0 then
                quirks[#quirks+1] = 'ecn'
                ecn = true
            end
    end
    
    -- tcp quirks
    if not ecn and (tcp.ns + tcp.cwr + tcp.ece) ~= 0 then
        quirks[#quirks + 1] = 'ecn'
    end

    return quirks
end

local function compose_sig(ip, tcp, tcp_options, syn_mss, payload)
    local sigip = get_sigip(ip)
    local sigtcp = get_sigtcp(ip, tcp, tcp_options, syn_mss)
    local quirks = get_quirks(ip, tcp)

    return p0f_tcpsig(sigip, sigtcp, quirks, payload)
end

-- luacheck: globals nf_tcpcap
function nf_tcpcap(frame, packet)
    local mac = nf.mac(frame)
    local ip = nf.ip(packet)

    if mac.src ~= 0 then
        local tcp, payload = nf.tcp(ip)
        local tcp_options = get_tcp_options(tcp)
        local sig = compose_sig(ip, tcp, tcp_options,
            syn_mss, payload)
        nf.sendsig('tcp', mac, ip, sig)
    end

    return false -- ALLOW
end
