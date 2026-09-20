-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local proxy = require("datamodel")
local utils = require("web.lte-utils")

local string, setmetatable = string, setmetatable

local function validate_pin(value)
	local errmsg = T"The PIN code must be composed of 4 to 8 digits."
	local pin = value:match("^(%d+)$")
	if pin ~= nil then
		if string.len(pin) >= 4 and string.len(pin) <= 8 then
			return true
		end
	end
	return false, errmsg
end

local function validate_puk(value)
	local errmsg = T"The PUK code must be composed of 8 to 16 digits."
	local pin = value:match("^(%d+)$")
	if pin ~= nil then
		if string.len(pin) >= 8 and string.len(pin) <= 16 then
			return true
		end
	end
	return false, errmsg
end

local current_pin_error = T"Please enter the correct current PIN."
local new_pin_error     = T"Please enter a correct new PIN."
local pin_verify_error  = T"Failed to verify the PIN code. Please make sure the current PIN is correct."
local pin_disable_error = T"Failed to disable the PIN code. Please make sure the current PIN is correct."
local pin_enable_error  = T"Failed to enable the PIN code. Please make sure the current PIN is correct."
local pin_change_error  = T"Failed to change the PIN code. Please make sure the current PIN is correct."
local puk_verify_error  = T"Failed to verify the PUK code. Please make sure you entered the correct PUK."

local function execute_action(post_data)
	local ret, msg
	if post_data["action"] == "default" then
		return true
	elseif post_data["action"] == "change" then
		ret, msg = validate_pin(post_data["old_pin"])
		if ret ~= true then
			return false, current_pin_error .. " " .. msg
		end
		ret, msg = validate_pin(post_data["new_pin"])
		if ret ~= true then
			return false, T"Please enter a valid new PIN." .. " " .. msg
		end
		ret = proxy.set("rpc.mobiled.device.@1.sim.pin.change", post_data["old_pin"] .. ',' .. post_data["new_pin"])
		if ret ~= true then
			return false, pin_change_error
		end
		return true
	elseif post_data["action"] == "disable" then
		ret, msg = validate_pin(post_data["pin"])
		if ret ~= true then
			return false, current_pin_error .. " " .. msg
		end
		ret = proxy.set("rpc.mobiled.device.@1.sim.pin.disable", post_data["pin"])
		if ret ~= true then
			return false, pin_disable_error
		end
		return true
	elseif post_data["action"] == "enable" then
		ret, msg = validate_pin(post_data["pin"])
		if ret ~= true then
			return false, current_pin_error .. " " .. msg
		end
		ret = proxy.set("rpc.mobiled.device.@1.sim.pin.enable", post_data["pin"])
		if ret ~= true then
			return false, pin_enable_error
		end
		return true
	elseif post_data["action"] == "unlock" then
		ret, msg = validate_pin(post_data["pin"])
		if ret ~= true then
			return false, current_pin_error .. " " .. msg
		end
		ret = proxy.set("rpc.mobiled.device.@1.sim.pin.unlock", post_data["pin"])
		if ret ~= true then
			return false, pin_verify_error
		end
		return true
	elseif post_data["action"] == "unblock" then
		ret, msg = validate_pin(post_data["pin"])
		if ret ~= true then
			return false, new_pin_error .. " " .. msg
		end
		ret, msg = validate_puk(post_data["puk"])
		if ret ~= true then
			return false, msg
		end
		ret = proxy.set("rpc.mobiled.device.@1.sim.pin.unblock", post_data["pin"] .. ',' .. post_data["puk"])
		if ret ~= true then
			return false, puk_verify_error
		end
		return true
	end
	return false
end

local post_data = ngx.req.get_post_args()
setmetatable(post_data, { __index = function() return "" end })
local ret, msg = execute_action(post_data)

local pinInfo = utils.getContent("rpc.mobiled.device.@1.sim.pin.")
pinInfo['pin_state_hr'] = utils.pin_state_map[pinInfo['pin_state']]

local simInfo = utils.getContent("rpc.mobiled.device.@1.sim.imsi")

local data = {
	status = ret,
	error = msg,
	pin_info = pinInfo,
	sim_info = simInfo
}

local buffer = {}
ret = json.encode (data, { indent = false, buffer = buffer })
if ret then
	utils.sendResponse(buffer)
end
utils.sendResponse("{}")
