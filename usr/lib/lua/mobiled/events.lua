---------------------------------
--! @file
--! @brief The events module which is responsible listening and acting on UBUS event
---------------------------------

local runtime, events
local json = require("dkjson")
local helper = require('mobiled.scripthelpers')

local M = {}

function M.init(callback, rt)
	runtime = rt
	events = {
		['mobiled'] = function(...) callback('mobiled', ...) end,
		['mobiled.network'] = function(...) callback('mobiled.network', ...) end,
		['mmpbxmobilenet.emergency'] = function(...) callback('mmpbxmobilenet.emergency', ...) end
	}
end

function M.start()
	runtime.ubus:listen(events)
end

function M.send_event(id, data)
	local ret = json.encode(data, { indent = false })
	if ret then
		local command = "ubus send " .. id .. " '" .. ret .. "'"
		runtime.log:info('Executing "' .. command .. '"')
		helper.capture_cmd(command)
	else
		runtime.log:error("Failed to encode data")
	end
end

return M

