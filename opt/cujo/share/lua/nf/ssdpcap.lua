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

-- luacheck: globals nf_ssdp
function nf_ssdp(frame, packet)
    local mac = nf.mac(frame)
    local ip = nf.ip(packet)

    if mac.src ~= 0 then
        local udp, payload = nf.udp(ip)
        if payload then
            local ok, err = nf.send('ssdp', {
                mac = nf.tomac(mac.src),
                ip = nf.toip(ip.src),
                payload = tostring(payload),
            })
            if not ok then
                debug("nflua: 'nf_ssdp' failed to send netlink msg 'ssdp': %s", err)
            end
        end
    end

    return true -- DROP
end
