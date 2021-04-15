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

local function capture(frame, packet, channel)
    local mac = nf.mac(frame)
    local ip = nf.ip(packet)
    local udp, payload = nf.udp(ip)

    local srcmac = nf.tomac(mac.src)
    local dstmac = nf.tomac(mac.dst)

    if srcmac == dstmac then
        debug("nflua: 'capture' found same srcmac %s and dstmac %s for '%s'", srcmac, dstmac, channel)
        return false
    end

    local ok, err = nf.send(channel, {
        source = {
            port = udp.sport,
            mac = srcmac,
            ip = nf.toip(ip.src),
        },
        destination = {
            port = udp.dport,
            mac = dstmac,
            ip = nf.toip(ip.dst),
        },
        payload = base64.encode(tostring(payload)),
    })
    if not ok then
        debug("nflua: 'capture' failed to send netlink msg '%s': %s", channel, err)
    end
    return false
end

-- For these protocols we just send the full payload to userspace.
-- luacheck: globals nf_dhcp nf_dns nf_mdns
function nf_dhcp(frame, packet) return capture(frame, packet, 'dhcp') end
function nf_dns(frame, packet) return capture(frame, packet, 'dns') end
function nf_mdns(frame, packet) return capture(frame, packet, 'mdns') end
