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

local function get_headers(req)
    local headers = {}

    -- name: [value] CRLF
    for name, value in string.gmatch(req, '([%w-_]+):%s*([^%c]*)%c+') do
        headers[name] = value
    end

    return headers
end

local function compose_sig(version, headers)
    local user_agent = headers['User-Agent']
    return user_agent and p0f_httpsig(version, user_agent) or nil
end

-- luacheck: globals nf_httpcap
function nf_httpcap(frame, packet)
    local mac = nf.mac(frame)
    local ip = nf.ip(packet)

    if mac.src ~= 0 then
        local tcp, payload = nf.tcp(ip)

        if payload then
            local request = tostring(payload)

            -- Method SP Uri SP HTTP-1.x [headers] CRLF [body]
            local method, version, hdrs = string.match(request,
                '([A-Z]+).*HTTP/1%.(%d)%c+(.*)')

            if version and method == 'HEAD' or method == 'GET' then
                local sig = compose_sig(version, get_headers(hdrs))
                if sig then
                    nf.sendsig('http', mac, ip, sig)
                end
            end
        end
    end

    return false -- ALLOW
end
