---------------------------------
--! @file
--! @brief The events module which is responsible listening and acting on UBUS event
---------------------------------

local runtime, cb
local type = type

local M = {}

function M.init(callback, rt)
	runtime = rt
	cb = callback
end

local function mobiled_event(msg)
	if type(msg) == "table" and msg.event then
		cb(msg)
	end
end

function M.start()
	-- Register UBUS events
	local events = {}
	events['mobiled'] = mobiled_event
	runtime.ubus:listen(events)
end

function M.send_event(id, data)
	local json = require("dkjson")
	local ret = json.encode (data, { indent = false })
	if ret then
		local helper = require('mobiled.scripthelpers')
		local command = "ubus send " .. id .. " '" .. ret .. "'"
		runtime.log:info(command)
		helper.capture_cmd(command)
	else
		runtime.log:error("Failed to encode data")
	end
end

return M

