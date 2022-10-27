local ubus = require("ubus")

local vid_mappings = {
	["12d1"] = "huawei",
	["19d2"] = "zte",
	["1bbb"] = "alcatel"
}

local Device = {}
Device.__index = Device

local M = {}

function Device:send_event(id, data)
	local conn = ubus.connect()
	if not conn then
		return nil, "Failed to connect to ubusd"
	end
	conn:send(id, data)
end

function M.create(runtime, params)
	local device = {
		runtime = runtime,
		dev_idx = params.dev_idx,
		desc = params.dev_desc,
		interfaces = {},
		state = {
			initialized = false
		},
		buffer = {
			pin_info = {},
			sim_info = {},
			device_info = {},
			ip_info = {},
			session_info = {},
			network_info = {},
			radio_signal_info = {},
			device_capabilities = {},
			profile_info = {}
		},
		session_state = {},
		web_info = {},
		errors = {}
	}

	if not params.pid or not params.vid then return nil, "Failed to match vid/pid" end

	device.vid = params.vid
	device.pid = params.pid

	if vid_mappings[device.vid] then
		local status, m = pcall(require, "libwebapi." .. vid_mappings[device.vid])
		if status and m then
			device.mapper = m.create(runtime, device.pid)
		else
			if type(m) == "string" then runtime.log:error(m) end
		end
	end

	setmetatable(device, Device)
	return device
end

return M
