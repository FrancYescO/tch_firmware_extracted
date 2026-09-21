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
-- luacheck: globals appblocker
-- luacheck: read globals gquic
-- luacheck: read globals dns
-- (ssdpcap exports no globals)

appblocker = {}
local blocked = {}

local portmap = {
    [nf.proto.tcp] = function(ip) return nf.tcp(ip).dport end,
    [nf.proto.udp] = function(ip) return nf.udp(ip).dport end,
}

function appblocker.add(set, id) blocked[set][id] = true end
function appblocker.del(set, id) blocked[set][id] = nil end
function appblocker.flush(set)
    blocked[set] = lru.new(config.appblocker.maxentries, config.appblocker.ttl)
end

-- luacheck: globals nf_appblocker
function nf_appblocker(frame, packet)
    -- This encoding must match the one used in cujo.appblocker.*.set.
    local ip = nf.ip(packet)
    local proto = ip.version == 4 and ip.protocol or ip.nh
    local map = portmap[proto]
    local port = map and map(ip) or 0
    local mac = nf.mac(frame).src
    local fmt = ip.version == 4 and 'I6Bc4I2' or 'I6Bc16I2'
    local id = string.pack(fmt, mac, proto, ip.dst, port)

    for k,_ in pairs(blocked) do
        if blocked[k][id] then return true end
    end
    return false
end
