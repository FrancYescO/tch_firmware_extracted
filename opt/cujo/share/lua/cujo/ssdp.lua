--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local base64 = require "base64"

local shims = require 'cujo.shims'
local util = require 'cujo.util'

-- Listen on the configured port for SSDP responses and create iptables rules
-- that pass those responses to nf_http, for both IPv4 and IPv6.
local socks = {}

local module = {reply = util.createpublisher()}

local timeout_cancel = nil

local remaining
local function reply(msg)
    local payload = base64.encode(msg.payload)
    remaining = math.max(remaining - #payload, 0)
    cujo.log:scan('SSDP reply received from ', msg.ip, ' (', remaining, ' bytes left)')
    cujo.ssdp.reply(msg.ip, msg.mac, payload)
    if remaining == 0 then module.cancel() end
end

function module.cancel()
    if timeout_cancel ~= nil then
        cujo.nf.unsubscribe('ssdp', reply)
        cujo.log:scan'done waiting SSDP replies'
        timeout_cancel()
        timeout_cancel = nil
    end
end

local addrs = {ip4 = '239.255.255.250', ip6 = 'ff02::c'}
local port = 1900
function module.scan(timeout, maxsize)
    if timeout_cancel ~= nil then
        timeout_cancel()
    end

    remaining = maxsize
    cujo.nf.subscribe('ssdp', reply)
    timeout_cancel = shims.create_oneshot_timer(
        "ssdp-timeouter", timeout,
        function(stopped)
            if not stopped then
                return module.cancel()
            end
        end)

    for _, set in pairs(socks) do
        for net, sock in pairs(set) do
            local addr = addrs[net]
            cujo.log:scan('sending SSDP request (timeout=', timeout, ') to ', addr)
            local host = net == 'ip4' and addr or '[' .. addr .. ']'
            local msg = 'M-SEARCH * HTTP/1.1\r\n' ..
                    'HOST: ' .. host .. ':' .. port .. '\r\n' ..
                    'MAN: "ssdp:discover"\r\n' ..
                    'MX: ' .. timeout .. '\r\n' ..
                    'ST: ssdp:all\r\n\r\n'
            shims.socket_send(sock, msg, addr, port, function(ok, err)
                if not ok then
                    cujo.log:error('unable to send SSDP request to ', host,
                        ' (', err, ')')
                end
            end)
        end
    end
end

function module.initialize()
    assert(cujo.config.getdevaddr, "missing porting defined getdevaddr function")
    assert(cujo.config.ssdpbindport, "missing SSDP bind port configuration")

    do
        local socktype = {ip4 = 'ipv4', ip6 = 'ipv6'}
        local function helper(iface, net)
            local ip = cujo.config.getdevaddr(iface, socktype[net])
            if not ip then return end

            local sock, err = shims.socket_create_udp(net)
            if not sock then error('creating socket: ' .. err) end

            local ok, err = shims.socket_setsockname(sock, ip, cujo.config.ssdpbindport)
            if not ok then
                error('failed to bind to ip/port ' .. ip .. '/' .. cujo.config.ssdpbindport .. ' :' .. err)
            end

            return sock
        end
        for _, iface in pairs(cujo.config.lan_ifaces) do
            local set = {}
            for net in pairs(cujo.config.nets) do
                local sock = helper(iface, net)
                if sock ~= nil then
                    set[net] = sock
                end
            end
            if next(set) then socks[iface] = set end
        end
    end
end

return module
