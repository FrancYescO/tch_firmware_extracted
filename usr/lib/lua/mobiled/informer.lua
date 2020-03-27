---------------------------------
--! @file
--! @brief The informer module which is responsible for polling devices and sending LED events
---------------------------------

local pairs = pairs
local runtime, timeout, leds

local M = {}

local function poll_devices()
    local devices = runtime.mobiled.get_devices()
    for _, device in pairs(devices) do
        device:periodic()
    end
end

local function event_leds()
    local devices = runtime.mobiled.get_devices()
    for _, device in pairs(devices) do
        if leds then
            runtime.ubus:send("mobiled.leds", leds.get_led_info(device))
        end
    end
end

local actions = {
    {
        handler = poll_devices,
        interval = 1,
        counter = 0
    },
    {
        handler = event_leds,
        interval = 10,
        counter = 0
    }
}

function M.timeout()
    for _, action in pairs(actions) do
        action.counter = action.counter + 1
        if action.counter >= action.interval then
            action.handler()
            action.counter = 0
        end
    end
    M.timer:set(timeout)
end

function M.init(rt)
    runtime = rt
    timeout = 1000

    local status, m = pcall(require, "mobiled.plugins.leds")
    leds = status and m or nil

    M.timer = runtime.uloop.timer(M.timeout)
end

function M.start()
    M.timer:set(timeout)
    runtime.ubus:send("mobiled", { event = "mobiled_started" })
end

return M
