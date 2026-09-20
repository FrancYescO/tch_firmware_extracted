--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo, globals cujo.nf

local json = require 'json'
local tabop = require 'loop.table'

local shims = require 'cujo.shims'
local util = require 'cujo.util'

local netlink

local module = {}

local scripts = {
    'nf.debug',
    'nf.lru',
    'nf.nf',
    'nf.threat',
    'nf.conn',
    'nf.safebro',
    'nf.ssl',
    'nf.http',
    'nf.caps',
    'nf.tcptracker',
    'nf.apptracker',
    'nf.p0f',
    'nf.httpcap',
    'nf.tcpcap',
    'nf.appblocker',
    'nf.gquic',
    'nf.dns',
    'nf.ssdpcap',
}
local mainchains = {}
local channels = tabop.memoize(util.createpublisher)

function module.subscribe(channel, handler) channels[channel]:subscribe(handler) end
function module.unsubscribe(channel, handler) channels[channel]:unsubscribe(handler) end

function module.enablemac(tablename, mac, add)
    cujo.nf.dostring(string.format('%s[%d] = %s',
        tablename, tonumber(string.gsub(mac, ':', ''), 16), add and true or nil))
end

-- Send the given Lua code over netlink to the kernel agent for execution.
-- Completes asynchronously. Note that the kernel agent is part of a separate
-- process so having successfully sent something does not guarantee that it has
-- been executed (or even will be executed, if we get shut down).
--
-- Params:
--   script   (string)   - the Lua code
--   callback (function) - called after the send is complete, receives a boolean
--                         indicating success and optional error information
--   path     (string)   - file path the Lua code is from, if any
--
-- Only the first parameter is required.
function module.dostring(script, callback, path)
    local payload = script
    if path ~= nil then payload = '@' .. path .. '\0' .. script end

    local on_sent = function (ok, err)
        if not ok then
            if path == nil then path = string.sub(script, 1, 20) end
            cujo.log:error("unable to send script '", path, "' to NFLua (", err, ')')
        end
        if callback ~= nil then
            return callback(ok, err)
        end
    end

    if cujo.config.nf.netlink.family == 16 then
        return shims.socket_send_nflua_generic(netlink, payload, 0, on_sent)
    else
        return shims.socket_send(netlink, payload, 0, nil, on_sent)
    end
end

function module.addrule(net, chain, rule) mainchains[chain][net]:append(rule) end

local function load_scripts_starting_at(i, on_all_loaded)
    local script = scripts[i]
    local path, err = package.searchpath(script, package.path)
    if not path then
        error("unable to find NFLua script '" .. script .. "' " .. err)
    end
    cujo.log:nflua('send script ', path)
    return cujo.nf.dostring(
        assert(cujo.filesys.readfrom(path, 'a')),
        function()
            if i == #scripts then
                return on_all_loaded()
            else
                return load_scripts_starting_at(i + 1, on_all_loaded)
            end
        end,
        path)
end

function module.initialize(on_nf_initialized)
    shims.socket_create_netlink(cujo.config.nf.netlink.family, cujo.config.nf.netlink.port, function(nl)
        netlink = nl

        local err
        err = shims.socket_set_recv_buf(netlink, cujo.config.nf_recv_buf_size)
        if err then
            cujo.log:error("Failed to set ", netlink, "recv buf: ", err)
        end
        err = shims.socket_set_send_buf(netlink, cujo.config.nf_send_buf_size)
        if err then
            cujo.log:error("Failed to set ", netlink, "send buf: ", err)
        end

        -- Initialize the kernel-side Lua environment, including providing
        -- cujo.config.nf as "config".
        --
        -- We clear the previous environment to ensure a clean slate by
        -- overriding _G's indexing to point to a freshly created table.
        local config_nf = cujo.util.serialize(cujo.config.nf)
        cujo.nf.dostring(
            string.format([[
                nf._ENV = {}
                setmetatable(_G, {__index = nf._ENV, __newindex = nf._ENV})
                debug_logging = %s
                config = %s]],
                cujo.log:flag('nflua_debug'),
                config_nf),
            function()
                cujo.nf.initialized = true
                return load_scripts_starting_at(1, function()
                    -- The base rules are required by later steps,
                    -- so initialize that here as well.
                    return cujo.nfrules.set('base', function()
                        cujo.nfrules.check('base')
                        return on_nf_initialized()
                    end)
                end)
            end)
        cujo.nf.subscribe('log', function(msg) cujo.log:warn(table.unpack(msg)) end)

        local function on_payload(ok, payload)
            if not ok then
                cujo.log:error('unable to receive payload from NFLua: ', payload)
                return
            end
            local channel, args = payload:match('(%w+) (.*)')
            local message
            if channel == 'apptracker' then
                cujo.log:nflua('got binary message for ', channel)
                message = args
            else
                cujo.log:nflua('got message ', payload)
                ok, message = pcall(json.decode, args)
                if not ok then
                    cujo.log:error('unable to decode json from NFLua: ', message)
                    return
                end
            end
            channels[channel](message)
        end
        if cujo.config.nf.netlink.family == 16 then
            shims.on_nflua_generic_payload(netlink, on_payload)
        else
            shims.on_nflua_payload(netlink, on_payload)
        end
    end)
end

return module
