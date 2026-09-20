--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local apptracker = require "cujo.apptracker"
local fingerprint = require "cujo.fingerprint"
local safebro = require "cujo.safebro"
local shims = require "cujo.shims"
local tcptracker = require "cujo.tcptracker"

local module = {}

local wakeup = function() return true end

-- Publishers that can trigger wakeup from hibernation.
local wakeevts = {
    [safebro.threat] = function () wakeup'safe browsing threat' end,
    [fingerprint.dhcp] = function () wakeup'DHCP request' end,
    [tcptracker.enable] = function (enabled)
        if enabled then wakeup'tcptracker enabled' end
    end,
    [apptracker.enable] = function (enabled)
        if enabled then wakeup'apptracker enabled' end
    end,
}

-- These two are used to trigger the corresponding callbacks in cujo.cloud, but
-- only once per hibernation/wakeup.
local function onhibernate()
    cujo.cloud.onhibernate()
    cujo.cloud.ondisconnect:unsubscribe(onhibernate)
end
local function onwakeup()
    cujo.cloud.onwakeup()
    cujo.cloud.onconnect:unsubscribe(onwakeup)
end

function module.cancel()
    -- Relies on the timer's stop function returning nil, so that this
    -- returns true when something actually happens.
    return not wakeup'cancel'
end

function module.start(duration)
    if cujo.tcptracker.synlistener.is_enabled() then
        cujo.log:hibernate'ignored hibernation because SYN listener is on'
        return 'synlistener'
    end

    cujo.cloud.ondisconnect:subscribe(onhibernate)
    cujo.log:hibernate('hibernating for ', duration, ' seconds')
    cujo.cloud.disconnect()
    for publisher, callback in pairs(wakeevts) do
        publisher:subscribe(callback)
    end

    wakeup = shims.create_oneshot_timer('hibernator', duration, function (_, reason)
        cujo.cloud.onconnect:subscribe(onwakeup)
        for publisher, callback in pairs(wakeevts) do
            publisher:unsubscribe(callback)
        end
        cujo.log:hibernate('hibernation ended due to ', reason or 'timeout')
        cujo.cloud.connect()
        wakeup = function() return true end
    end)
end

return module
