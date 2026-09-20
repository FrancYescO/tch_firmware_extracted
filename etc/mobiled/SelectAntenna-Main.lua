local M = {
	averaging_count = 5,
	current_antenna = "internal",
	antenna_measurements = {
		internal = {},
		external = {}
	}
}

M.SenseEventSet = {
	"device_disconnected",
	"device_config_changed",
	"antenna_change_detected",
	"sim_removed"
}

local function average(t)
	local elements = 0
	local sum = 0
	for k, v in pairs(t) do
		sum = sum + v
		elements = elements + 1
	end
	if not elements then return 0 end
	return sum / elements
end

local function clear_module()
	M.current_antenna = "internal"
	M.antenna_measurements = {
		internal = {},
		external = {}
	}
end

function M.check(runtime, event, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	if not mobiled.platform then
		return "RegisterNetwork"
	end

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "WaitDeviceDisconnect"
	end

	local antenna_controls = mobiled.platform.get_linked_antenna_controls(device)
	if #antenna_controls == 0 then
		log:info("No antenna selection for this device")
		return "RegisterNetwork"
	end

	local main_antenna
	for _, antenna in pairs(antenna_controls) do
		if antenna.name == "main" then
			log:info("Using antenna " .. antenna.id .. " as main")
			main_antenna = antenna
		end
	end

	if not main_antenna then
		log:error("No main antenna for this device!")
		return "RegisterNetwork"
	end

	if main_antenna.detector_type == "electronic" and main_antenna.external_detected then
		if main_antenna.external_detected() then
			log:info("Detected external antenna on main")
			main_antenna.auto_selected_antenna = "external"
		else
			log:info("Detected internal antenna on main")
			main_antenna.auto_selected_antenna = "internal"
		end
	end

	local config = mobiled.get_config()
	if config and config.platform then
		if config.platform.antenna ~= "auto" then
			clear_module()
			for _, antenna in pairs(antenna_controls) do
				antenna.auto_selected_antenna = nil
				log:info('Using "' .. config.platform.antenna .. '" antenna for ' .. antenna.name)
				antenna.select_antenna(config.platform.antenna)
			end
			return "RegisterNetwork"
		elseif main_antenna.auto_selected_antenna then
			for _, antenna in pairs(antenna_controls) do
				log:info('Using automatically selected "' .. main_antenna.auto_selected_antenna .. '" antenna for ' .. antenna.name)
				antenna.select_antenna(main_antenna.auto_selected_antenna)
			end
			return "RegisterNetwork"
		end
	end

	if event.event == "timeout" then
		if #M.antenna_measurements.internal >= M.averaging_count then
			M.current_antenna = "external"
		end

		log:info("Using " .. M.current_antenna .. " antenna for measurement")
		main_antenna.select_antenna(M.current_antenna)

		local info = device:get_radio_signal_info()
		if info then
			-- We have to insert a default if no RSSI is available in order not to get stuck in this state
			table.insert(M.antenna_measurements[M.current_antenna], info.rssi or -140)
		end

		if #M.antenna_measurements.internal >= M.averaging_count and #M.antenna_measurements.external >= M.averaging_count then
			local internal = average(M.antenna_measurements.internal)
			local external = average(M.antenna_measurements.external)
			local selected = "internal"
			if external >= internal then
				selected = "external"
			end

			log:info("Average for internal antenna: " .. internal)
			log:info("Average for external antenna: " .. external)
			log:info("Selected " .. selected .. " antenna")
			main_antenna.auto_selected_antenna = selected
			main_antenna.select_antenna(main_antenna.auto_selected_antenna)

			-- Reset for next time
			clear_module()
			return "RegisterNetwork"
		end
	elseif event.event == "device_disconnected" then
		-- Reset for next time
		clear_module()
		return "DeviceRemove"
	elseif (event.event == "device_config_changed") then
		-- Reset for next time
		clear_module()
		return "DeviceConfigure"
    elseif (event.event == "sim_removed") then
		-- Reset for next time
		clear_module()
		return "SimInit"
	end

	return "SelectAntenna"
end

return M
