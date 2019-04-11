local M = {}

M.SenseEventSet = {
	"device_disconnected",
	"device_config_changed",
	"antenna_change_detected",
	"atenna_selection_done",
	"platform_config_changed",
	"sim_removed"
}

local measurement_interval = 6000

local function average(t)
	local elements = 0
	local sum = 0
	for _, v in pairs(t) do
		sum = sum + v
		elements = elements + 1
	end
	if elements == 0 then return 0 end
	return sum / elements
end

-- Check if we have enough measurements in the same radio access technology
local function enough_measurements(antenna_measurements)
	local most_relevant_rat
	local count = 0
	for rat, measurements in pairs(antenna_measurements) do
		if #measurements > count then
			most_relevant_rat = rat
			count = #measurements
		end
	end
	if count >= 3 then
		return most_relevant_rat
	end
end

local function perform_measurement(runtime, device, main_antenna)
	local log = runtime.log

	local state_data = device.sm:get_state_data()

	log:info("Using " .. state_data.current_antenna .. " antenna for measurement")

	local info = device:get_radio_signal_info()
	if info and info.radio_interface and info.rssi then
		if not state_data.antenna_measurements[state_data.current_antenna][info.radio_interface] then
			state_data.antenna_measurements[state_data.current_antenna][info.radio_interface] = {}
		end
		log:info("Measured %ddBm on %s antenna", info.rssi, state_data.current_antenna)
		table.insert(state_data.antenna_measurements[state_data.current_antenna][info.radio_interface], info.rssi)
	end

	-- Check if we have at least three valid measurements on both internal and external antenna
	-- Switch to external antenna and toggle device power mode to reset LTE module scanning procedure
	local valid_external_rat = enough_measurements(state_data.antenna_measurements.external)
	if valid_external_rat and state_data.current_antenna == "external" then
		state_data.current_antenna = "internal"
		main_antenna.select_antenna(state_data.current_antenna)
	end
	local valid_internal_rat = enough_measurements(state_data.antenna_measurements.internal)
	if valid_internal_rat and valid_external_rat then
		local selected = "internal"
		if valid_internal_rat == valid_external_rat then
			local internal_rssi = average(state_data.antenna_measurements.internal[valid_internal_rat])
			local external_rssi = average(state_data.antenna_measurements.external[valid_external_rat])
			log:info("Average for internal antenna: " .. internal_rssi)
			log:info("Average for external antenna: " .. external_rssi)
			if external_rssi > internal_rssi then
				selected = "external"
			end
		else
			log:info("Radio technology for internal antenna measurements doesn't match with external")
		end

		log:info("Selected " .. selected .. " antenna")
		device.main_antenna.auto_selected_antenna = selected
		main_antenna.select_antenna(device.main_antenna.auto_selected_antenna)
		runtime.events.send_event("mobiled", { event = "atenna_selection_done", dev_idx = device.sm.dev_idx })
		return
	end
	state_data.measurement_timer:set(measurement_interval)
end

function M.check(runtime, event, dev_idx)
	if event.event == "device_disconnected" then
		return "DeviceRemove"
	elseif event.event == "device_config_changed" then
		return "DeviceConfigure"
	elseif event.event == "sim_removed" then
		return "SimInit"
	elseif event.event == "atenna_selection_done" then
		return "RegisterNetwork"
	end

	local mobiled = runtime.mobiled
	local log = runtime.log

	if not mobiled.platform then
		log:info("No antenna selection for this device")
		return "RegisterNetwork"
	end

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	local antenna_control = mobiled.platform.get_linked_antenna_control(device)
	if not antenna_control or not antenna_control.antenna then
		log:info("No antenna selection for this device")
		return "RegisterNetwork"
	end

	if not device.main_antenna then
		device.main_antenna = {}
	end

	local main_antenna
	for _, antenna in pairs(antenna_control.antenna) do
		if antenna.name == "main" then
			main_antenna = antenna
		end
	end

	if not main_antenna then
		log:error("No main antenna defined for this device")
		log:error("Skipping antenna selection")
		return "RegisterNetwork"
	end

	if main_antenna.detector_type == "electronic" and main_antenna.external_detected then
		if main_antenna.external_detected() then
			log:info("Detected external antenna on main")
			device.main_antenna.auto_selected_antenna = "external"
		else
			log:info("Detected internal antenna on main")
			device.main_antenna.auto_selected_antenna = "internal"
		end
	end

	local config = mobiled.get_config()
	if config and config.platform then
		if config.platform.antenna ~= "auto" then
			device.main_antenna.auto_selected_antenna = nil
			for _, antenna in pairs(antenna_control.antenna) do
				log:info('Using "' .. config.platform.antenna .. '" antenna for ' .. antenna.name)
				antenna.select_antenna(config.platform.antenna)
			end
			return "RegisterNetwork"
		elseif device.main_antenna.auto_selected_antenna then
			for _, antenna in pairs(antenna_control.antenna) do
				log:info('Using automatically selected "' .. device.main_antenna.auto_selected_antenna .. '" antenna for ' .. antenna.name)
				antenna.select_antenna(device.main_antenna.auto_selected_antenna)
			end
			return "RegisterNetwork"
		end
	end

	if event.event == "timeout" then
		-- In order to do antenna detection based on RSSI measurements, the radio needs to be turned on
		local rf_control = mobiled.platform.get_linked_rf_control(device)
		if rf_control and rf_control.enable then
			rf_control.enable()
		end

		local state_data = device.sm:get_state_data()

		if state_data.measurement_timer then
			state_data.measurement_timer:cancel()
			state_data.measurement_timer = nil
			log:warning("Timeout detecting best antenna. Falling back to internal")
			device.main_antenna.auto_selected_antenna = "internal"
			main_antenna.select_antenna(device.main_antenna.auto_selected_antenna)
			return "RegisterNetwork"
		end

		if not state_data.current_antenna or not state_data.antenna_measurements then
			log:info("Starting antenna detection")
			state_data.current_antenna = "external"
			state_data.antenna_measurements = {
				internal = {},
				external = {}
			}
			main_antenna.select_antenna(state_data.current_antenna)
			state_data.measurement_timer = runtime.uloop.timer(function()
				perform_measurement(runtime, device, main_antenna)
			end, measurement_interval)
		end
	end

	return "SelectAntenna"
end

return M
