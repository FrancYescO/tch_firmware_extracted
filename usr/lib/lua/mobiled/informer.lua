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

local function update_led()
	local devices = runtime.mobiled.get_devices()
	for _, device in pairs(devices) do
		if leds then
			local led_info = leds.get_led_info(device)
			if type(led_info) == "table" then
				led_info.dev_idx = device.sm.dev_idx
				runtime.ubus:send("mobiled.leds", led_info)
			end
		end
	end
end

local actions = {
	{
		name = "poll_devices",
		handler = poll_devices,
		interval = 1,
		counter = 0
	},
	{
		name = "led_update",
		handler = update_led,
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

	local config = runtime.config.get_config()
	for _, action in pairs(actions) do
		if action.name == "led_update" then
			action.interval = config.led_update_interval or action.interval
		end
	end
	M.timer = runtime.uloop.timer(M.timeout)
end

function M.start()
	M.timer:set(timeout)
	runtime.ubus:send("mobiled", { event = "mobiled_started" })
end

return M
