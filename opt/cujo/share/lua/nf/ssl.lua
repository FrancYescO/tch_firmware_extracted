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
-- luacheck: globals ssl
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

-- Overview: nf_lua match extension, focused on extracting the server hostname
-- from the SSL server_name extension.
--
-- Sources:
-- https://tools.ietf.org/html/rfc5246#section-7.4.1.2
-- http://blog.fourthbit.com/2014/12/23/traffic-analysis-of-an-ssl-slash-tls-session
-- https://tools.ietf.org/html/rfc6066#section-3

local SSL_HANDSHAKE = 0x16
local SSL_CLIENT_HELLO = 0x01

local OCTET = {0, 8}
local HEXTET = {0, 16, 'net'}

ssl = {}

ssl.layout = data.layout{
    record_type  = { 0,  8},
    handshk_type = {40,  8, 'net'},
    handshk_len  = {48, 24, 'net'},
    handshk_ver  = {72, 16, 'net'},
    random       = {88, 32 * 8, 'net'},
    sid_len      = {344, 8, 'net'},
}

local server_name = data.layout{
    id      = { 0, 16, 'net'},
    len     = {16, 16, 'net'},
    ext_len = {32, 16, 'net'},
    ext_id  = {48,  8, 'net'},
}

function ssl.extract_hostname(payload)
    local cipher = payload:segment(44 + payload.sid_len)
    if not cipher then return false end

    cipher:layout{len = HEXTET}

    local compression = cipher:segment(2 + cipher.len)
    if not compression then return false end

    compression:layout{len = OCTET}

    local extension = compression:segment(1 + compression.len + 2)
    if not extension then return false end

    repeat
        extension:layout(server_name)

        if extension.id == 0 and extension.ext_id == 0 then
            if extension.ext_len <= 3 then return false end
            local len = extension.ext_len - 3
            local hostname = extension:segment(9, len)
            return tostring(hostname)
        end

        extension = extension:segment(extension.len + 4)
    until not extension

    return false
end

function ssl.is_client_hello(payload)
    return payload ~= nil and payload.record_type == SSL_HANDSHAKE and
        payload.handshk_type == SSL_CLIENT_HELLO
end

local invalid_reply = ('\255'):rep(256)

local function blockpage() return invalid_reply end

-- luacheck: globals nf_ssl
function nf_ssl(frame, packet)
    local id = nf.connid()
    local state = conn.getstate(id)
    if state ~= 'init' then return end

    local ip = nf.ip(packet)
    local tcp, payload = nf.tcp(ip, ssl.layout)

    local host = ssl.is_client_hello(payload) and ssl.extract_hostname(payload)

    local mac = nf.mac(frame).src
    if not host or threat.iswhitelisted(mac, host) then
        conn.setstate(id, 'allow')
    else
        conn.filter(mac, ip.src, host, '', blockpage)
    end
end
