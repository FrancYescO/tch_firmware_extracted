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

-- luacheck: globals activemac
activemac = {}

-- Timer for sending to userspace.
local tim = false

-- "cache" is a mapping from connection IDs to our connection entries, for
-- connections where we are still waiting for more data. If we reach the
-- maximum, we count the connections that we had to forget about in "evicted".
--
-- "entries" is a list of entries that we have fully parsed and are ready to
-- send to userspace. This has the same maximum size as "cache", but the maximum
-- is handled in a manual way since there is no need for this to be an LRU. The
-- number of connections forgotten from "entries" are summed into "dropped".
--
-- The entry values themselves are tables containing some generic data like IP
-- and port numbers as well as the application-specific data, including any
-- intermediate things needed while parsing as well as the final parsed values.
local dropped = 0
local entries = {}
local evicted = 0

local function print_queue_state(name, time_stamp, size)
    debug("#### %s time : %s size : %s ",name,time_stamp,size)
end

local cache = lru.new(config.apptracker.maxentries, nil, function()
    evicted = evicted + 1 end, print_queue_state, 'nf_apptracker_cache')

local tmpfields = {'previous', 'method', 'referer', 'stage', 'notssl'}
local httpfields = {'host', 'target', 'user-agent'}

-- Parsers for TCP connections. Each one is tried in turn initially.
local parsers = {
    function (entry, payload)
        if entry.notssl then return end
        local segpayload = payload:layout(ssl.layout)
        if ssl.is_client_hello(segpayload) then
            entry.sni = ssl.extract_hostname(segpayload)
            if entry.sni then return 'ssl' end
        end
        entry.notssl = true
    end,
    function (entry, payload)
        if entry.stage == 'done' or entry.stage == 'error' then return end
        local info = http.headerinfo(entry, tostring(payload))
        return (info == 'done' and entry.method == 'GET' and entry.host) and
            'http' or info == 'notdone'
    end,
}

local function parsetcp(entry, payload)
    local done = true
    for _, f in ipairs(parsers) do
        local status = f(entry, payload)
        if type(status) == 'string' then return status end
        if status then done = false end
    end
    return done
end

local function send()
    if dropped > 0 or evicted > 0 then
        debug('apptracker dropped:%s evicted:%s', dropped, evicted)
        dropped = 0
        evicted = 0
    end
    local send_count = math.min(config.apptracker.max_entries_send, #entries)
    local msg = string.pack("I4", send_count) .. table.concat(entries, "", 1, send_count)
    local ok, err = nf.send_raw('apptracker', msg)
    if not ok then
        debug("nflua: 'send' failed to send netlink msg 'apptracker': %s", err)
    end

    if send_count == #entries then
        tim = false
        entries = {}
    else
        table.move(entries, send_count + 1, #entries, 1)
        for i = #entries, #entries - send_count + 1, -1 do
            entries[i] = nil
        end
        tim = timer.create(config.apptracker.timeout * 1000, send)
    end
end

local function extractl4andlower(proto, packet)
    local ip = nf.ip(packet)
    return ip, nf[proto](ip)
end

local function encode_ip(ip)
    if ip.version == 4 then
        return string.pack("I1c4c4", ip.version, ip.src, ip.dst)
    else
        return string.pack("I1c16c16", ip.version, ip.src, ip.dst)
    end
end

local function submit(entry, proto, frame, ip, l4data)
    entries[#entries + 1] =
        encode_ip(ip) ..
        string.pack("I1I2I6sssss",
            nf.proto[proto], -- I1
            l4data.sport, -- I2
            nf.mac(frame).src, -- I6
            -- strings
            entry.host or "",
            entry.target or "",
            entry['user-agent'] or "",
            entry.sni or "",
            entry.gquicua or ""
        )
    tim = tim or timer.create(config.apptracker.timeout * 1000, send)
end

local function regflow(id, entry, frame, packet)
    local ip, l4data, payload = extractl4andlower('tcp', packet)
    if not payload then return end
    local status = parsetcp(entry, payload)
    if status ~= false then cache[id] = nil end
    if type(status) ~= 'string' then return end
    if #entries >= config.apptracker.maxentries then
        dropped = dropped + 1
        return
    end

    for _, f in ipairs(tmpfields) do entry[f] = nil end
    if status ~= 'http' then
        for _, f in ipairs(httpfields) do entry[f] = nil end
    end
    submit(entry, 'tcp', frame, ip, l4data)
end

-- luacheck: globals nf_apptracker_new_tcp
function nf_apptracker_new_tcp(frame, packet)
    local id = nf.connid()
    local mac = nf.mac(frame).src
    if not activemac[mac] then
        cache[id] = nil
        return true
    end
    local entry = {}
    cache[id] = entry
    regflow(id, entry, frame, packet)
    return true
end

-- luacheck: globals nf_apptracker_tcp
function nf_apptracker_tcp(frame, packet)
    local mac = nf.mac(frame).src
    if not activemac[mac] then return end
    local id = nf.connid()
    local entry = cache[id]
    if entry then regflow(id, entry, frame, packet) end
end

-- luacheck: globals nf_apptracker_new_udp
function nf_apptracker_new_udp(frame, packet)
    local id = nf.connid()
    local mac = nf.mac(frame).src
    if not activemac[mac] then
        cache[id] = nil
        return true
    end
    if #entries >= config.apptracker.maxentries then
        dropped = dropped + 1
        cache[id] = true
        return true
    end
    local ip, l4data, payload = extractl4andlower('udp', packet)
    local entry = {}
    if payload then
        entry.sni, entry.gquicua = gquic.parse(payload)
        if entry.sni or entry.gquicua then
            submit(entry, 'udp', frame, ip, l4data)
        end
    end
    cache[id] = not (entry.sni or entry.gquicua) or nil
    return true
end

-- luacheck: globals nf_apptracker_udp
function nf_apptracker_udp(frame, packet)
    local id = nf.connid()
    if cache[id] == nil then return end
    if #entries >= config.apptracker.maxentries then
        dropped = dropped + 1
        return
    end

    local ip, l4data, payload = extractl4andlower('udp', packet)
    if not payload then return end
    local entry = {}
    entry.sni, entry.gquicua = gquic.parse(payload)
    if not entry.sni and not entry.gquicua then return end
    submit(entry, 'udp', frame, ip, l4data)
    cache[id] = nil
end

-- luacheck: globals nf_apptracker_dns
function nf_apptracker_dns(_, packet)
    local _, _, payload = extractl4andlower('udp', packet)
    if not payload then return end
    local domain, hosts = dns.parse(payload)
    if domain and #hosts > 0 then
        for i, ip in ipairs(hosts) do
            hosts[i] = nf.toip(ip)
        end
        local ok, err = nf.send('dnscache', {domain = domain, hosts = hosts})
        if not ok then
            debug("nflua: 'nf_apptracker_dns' failed to send netlink msg 'dnscache': %s", err)
        end
    end
end

-- luacheck: globals nf_enable_queues_debug
function nf_enable_queues_debug()
    cache:enable_debug()
end

-- luacheck: globals nf_disable_queues_debug
function nf_disable_queues_debug()
    cache:disable_debug()
end
