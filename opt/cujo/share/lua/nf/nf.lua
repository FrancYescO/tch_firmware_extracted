--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- This module must be executed first, because it creates the "nf" global and
-- also requires any external libraries.

collectgarbage('setpause', 75)

-- luacheck: new globals nf base64 json timer

nf = require'nf'

base64 = require'base64'
json = require'json'
timer = require'timer'

-- luacheck: not globals nf base64 json timer (set in the standard stanza below instead)

-- Standard luacheck globals stanza based on what NFLua preloads and
-- the order in which cujo.nf loads these scripts.
--
-- luacheck: read globals config data
-- luacheck: read globals base64 json timer
-- luacheck: read globals debug debug_logging
-- luacheck: read globals lru
-- luacheck: globals nf
-- luacheck: read globals threat
-- luacheck: read globals conn
-- luacheck: read globals safebro sbconfig
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

-- Sends a message to userspace over the netlink socket.
function nf.send_raw(cmd, data)
    local msg = cmd .. " " .. data
    if config.netlink.family == 16 then
        return pcall(nf.genetlink, msg, config.netlink.port)
    else
        return pcall(nf.netlink, msg, config.netlink.port)
    end
end

function nf.send(cmd, data, binary)
    return nf.send_raw(cmd, json.encode(data or '{}', binary))
end

function nf.segment(data, layout, offset)
    local seg = data:segment(offset)
    if seg and layout then seg:layout(layout) end
    return seg
end

local mac = data.layout{
    dst  = {   0, 6*8, 'net'},
    src  = { 6*8, 6*8, 'net'},
    type = {12*8, 2*8, 'net'},
}

function nf.mac(frame)
    return nf.segment(frame, mac)
end

local ipv = {
    [4] = data.layout{
        version  = {   0,   4},
        ihl      = {   4,   4},
        tos      = {   8,   6},
        ecn      = {  14,   2},
        tot_len  = {  16,  16, 'net'},
        id       = {  32,  16, 'net'},
        flags    = {  48,   3},
        frag_off = {  51,  13, 'net'},
        ttl      = {  64,   8},
        protocol = {  72,   8},
        check    = {  86,  16, 'net'},
        src      = {  12,   4, 'string'},
        dst      = {  16,   4, 'string'},
    },
    [6] = data.layout{
        version = {   0,   4},
        tc      = {   4,   8},
        fl      = {  12,  20, 'net'},
        tot_len = {  32,  16, 'net'},
        nh      = {  48,   8},
        hl      = {  56,   8},
        src     = {   8,  16, 'string'},
        dst     = {  24,  16, 'string'},
    },
}

-- Matches IPPROTO_TCP and IPPROTO_UDP in Linux. Expected to fit in 8 bits.
nf.proto = {
    tcp    = 6,
    udp    = 17,
}

local protos = {
    [nf.proto.tcp] = 'TCP',
    [nf.proto.udp] = 'UDP',
}

local iplen = {
    [4] = function (ip)
        return ip.ihl * 4
    end,
    [6] = function (ip)
        local len = 40
        local opt_len = 8

        if protos[ip.nh] then
            return len
        end

        local ext_header = data.layout{nh = {0, 8}}
        local option
        repeat
            option = nf.segment(ip, ext_header, len)
            len = len + opt_len
        until protos[option.nh] or len >= ip.tot_len

        return len
    end,
}

function nf.ip(packet)
    local layout = data.layout{version = {0, 4}}
    local ip = nf.segment(packet, layout)
    return nf.segment(packet, ipv[ip.version])
end

local tcp = data.layout{
    sport  = {   0, 2*8, 'net'},
    dport  = { 2*8, 2*8, 'net'},
    seqn   = { 4*8, 4*8, 'net'},
    ackn   = { 8*8, 4*8, 'net'},
    doff   = {12*8,   4},
    ns     = { 103,   1},
    cwr    = { 104,   1},
    ece    = { 105,   1},
    flags  = { 106,   6},
    urg    = { 106,   1},
    ack    = { 107,   1},
    psh    = { 108,   1},
    rst    = { 109,   1},
    syn    = { 110,   1},
    fin    = { 111,   1},
    window = {14*8, 2*8, 'net'},
    check  = {16*8, 2*8, 'net'},
    urgp   = {18*8, 2*8, 'net'},
}

function nf.tcp(ip, proto)
    local tcp = nf.segment(ip, tcp, iplen[ip.version](ip))
    return tcp, nf.segment(tcp, proto, tcp.doff * 4)
end

local udp = data.layout{
    sport = {  0, 16, 'net'},
    dport = { 16, 16, 'net'},
    len = { 32, 16, 'net'},
    crc = { 48, 16, 'net'}
}

function nf.udp(ip, proto)
    local udp = nf.segment(ip, udp, iplen[ip.version](ip))
    return udp, nf.segment(udp, proto, 8)
end

local function tobytes(n, m)
    local bytes = {}

    for i = 0, m - 1 do
        bytes[m - i] = (n >> i * 8) & 0xFF
    end

    return table.unpack(bytes)
end

local int16 = data.layout{
    int16 = { 0, 2*8, 'net'},
    byte1 = { 0,  8,  'net'},
    byte2 = { 8,  8,  'net'}
}

nf.ispublic = {
    [4] = function (ip)
        local ip = data.new(ip)
        ip:layout(int16)
        return not (ip.byte1 == 10 or -- class A
            (ip.byte1 == 172 and ip.byte2 >= 16 and ip.byte2 <= 31) or -- class B
            (ip.byte1 == 192 and ip.byte2 == 168)) -- class C
            and ip
    end,
    [6] = function (ip)
        local ip = data.new(ip)
        ip:layout(int16)
        return not (ip.int16 >= 0xfc00 and ip.int16 <= 0xfdff) and ip
    end
}

-- Converts a binary IP(v4/v6) address to a string.
function nf.toip(address)
    if #address == 4 then
        return string.format('%d.%d.%d.%d', address:byte(1, 4))
    end
    return string.format('%x:%x:%x:%x:%x:%x:%x:%x',
        string.unpack('>I2I2I2I2I2I2I2I2', address))
end

function nf.tomac(address)
    -- on kernel version 3.4.11-rt-19 packets originating from PPP with
    -- the interface in promiscuous mode, don't have a mac address set.
    -- Instead of failing we should set a dummy MAC and watch this cloud side
    if address == nil then
        return '02:00:00:FA:CE:00'
    end
    return string.format('%02X:%02X:%02X:%02X:%02X:%02X', tobytes(address, 6))
end

-- cache for tcpsigs and httpsigs already sent
local sigs = lru.new(1024, 24 * 60 * 60)

function nf.sendsig(proto, mac, ip, sig)
    local key = string.format('%s%x%s%s', proto, mac.src, ip.src, sig)
    if not sigs[key] then
        local ok, err = nf.send(proto, {
            mac = nf.tomac(mac.src),
            ip = nf.toip(ip.src),
            signature = sig,
        })
        if ok then
            sigs[key] = true
        else
            debug("nflua: 'nf.sendsig' failed to send netlink msg '%s': %s", proto, err)
        end
    end
end
function nf.log(...) nf.send('log', {...}) end
