-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local utils = require("web.lte-utils")

local redirect_sim, status, no_device, radio_interface, bars, signal_quality

local result = utils.getContent("rpc.mobiled.DeviceNumberOfEntries")
local devices = tonumber(result.DeviceNumberOfEntries)
if not devices or devices == 0 then
	no_device = utils.string_map["no_device"]
else
	local dev_idx = 1
	local rpc_path = string.format("rpc.mobiled.device.@%d.", dev_idx)

	result = utils.getContent(rpc_path .. "status")
	if result then
		if result.status ~= "Disabled" then
			status = utils.mobiled_state_map[result.status]
			result = utils.getContent(rpc_path .. "radio.signal_quality.radio_interface")
			radio_interface = utils.radio_interface_map[result.radio_interface]
			result = utils.getContent(rpc_path .. "leds.")
			bars = result.bars
			signal_quality = utils.signal_quality_map[bars]
			result = utils.getContent("rpc.mobiled.device.@1.sim.sim_state")
			if result.sim_state == "ready" or result.sim_state == "locked" or result.sim_state == "blocked" then
				result = utils.getContent("rpc.mobiled.device.@1.sim.pin.pin_state")
				if result.pin_state == "enabled_not_verified" or result.pin_state == "blocked" then
					redirect_sim = true
					if result.pin_state == "enabled_not_verified" then
						status = T"Please enter PIN"
					else
						status = T"Please enter PUK"
					end
				end
			end
		end
	end
end

local data = {
	status = status or "",
	no_device = no_device or "",
	radio_interface = radio_interface or "",
	signal_quality = signal_quality or "",
	bars = bars or "",
	redirect_sim = redirect_sim or "false"
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	utils.sendResponse(buffer)
end
utils.sendResponse("{}")
