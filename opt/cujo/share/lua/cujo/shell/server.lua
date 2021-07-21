--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local json = require "json"
local vararg = require "vararg"

local shims = require "cujo.shims"

local function sendmsg(write, kind, ...)
    local msg = json.encode{type = kind, args = {...}}
    local ok, err = write(msg)
    if not ok then
        if kind == 'print' then
            cujo.log:warn('rabidctl unable to print to disconnected client: ', ...)
        else
            cujo.log:error('rabidctl failed send reply: ', err)
        end
    end
end

local function sendresult(write, ok, ...)
    if ok then
        sendmsg(write, 'ret', vararg.map(tostring, ...))
    else
        sendmsg(write, 'err', 'exec', ...)
    end
end

local function handler(data, is_async, write)
    local ok, msg = pcall(json.decode, data)
    if not ok then
        cujo.log:error('rabidctl failed to decode message: ', msg)
        return false
    end

    -- Include json in the env here because it's very commonly used.
    local env = {json = json}

    if is_async then
        env.async_cb = function(...)
            return sendmsg(write, 'ret', vararg.map(tostring, ...))
        end
    end

    local f, err = load(msg.code, msg.name, 't', env)
    if not f then
        sendmsg(write, 'err', 'load', err)
    else
        function env.print(...)
            sendmsg(write, 'print', vararg.map(tostring, ...))
        end
        setmetatable(env, {__index = _G})
        local result = table.pack(xpcall(f, debug.traceback, table.unpack(msg.args)))
        if not is_async or not result[1] then
            sendresult(write, table.unpack(result))
        end
    end
    return true
end

local module = {}

function module.initialize()
    local sockpath = cujo.config.rabidctl.sockpath
    os.remove(sockpath)
    shims.run_shell_server(
        sockpath,
        cujo.config.rabidctl.timeout,
        function(...) cujo.log:error(...) end,
        handler)
end

return module
