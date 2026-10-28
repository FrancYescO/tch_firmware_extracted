---------------------------------
--! @file
--! @brief The platform module giving access to platform specific methods
---------------------------------

local runtime, plugin

local M = {}

function M.get_capabilities()
	if plugin then
		return plugin.get_platform_capabilities()
	end
	return {}
end

local function get_linked_capability(device, cap_type)
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info[cap_type] then
			for _, cap in pairs(info[cap_type]) do
				if cap.linked_device and cap.linked_device.dev_desc == device.desc then
					return cap
				end
			end
		end
	end
end

function M.get_linked_antenna_control(device)
	return get_linked_capability(device, "antenna_controls")
end

function M.get_linked_rf_control(device)
	return get_linked_capability(device, "rf_controls")
end

function M.get_linked_power_control(device)
	return get_linked_capability(device, "power_controls")
end

function M.get_linked_voice_interface(device)
	return get_linked_capability(device, "voice")
end

function M.sim_hotswap_supported(device)
	return get_linked_capability(device, "sim_hotswap") ~= nil
end

function M.get_linked_network_interfaces(device)
	return get_linked_capability(device, "network_interfaces")
end

local function power_control_action(action)
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.power_controls then
			for _, power_control in pairs(info.power_controls) do
				if power_control[action] then
					power_control[action]()
				end
			end
		end
	end
end

function M.power_all_on()
	power_control_action("power_on")
end

function M.power_all_off()
	power_control_action("power_off")
end

function M.reset_all()
	power_control_action("reset")
end

function M.get_capabilities()
	local capabilities = {}
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info then
			if info.power_controls then
				capabilities.power_controls = {}
				for _, power_control in pairs(info.power_controls) do
					local cap = { linked_device = power_control.linked_device, power_on = false, power_off = false, reset = false, power_state = false }
					cap.power_on = not not power_control.power_on
					cap.power_off = not not power_control.power_off
					cap.reset = not not power_control.reset
					cap.power_state = not not power_control.power_state
					table.insert(capabilities.power_controls, cap)
				end
			end
			if info.rf_controls then
				capabilities.rf_controls = {}
				for _, rf_control in pairs(info.rf_controls) do
					local cap = { linked_device = rf_control.linked_device, enable = false, disable = false, rf_state = false }
					cap.enable = not not rf_control.enable
					cap.disable = not not rf_control.disable
					cap.rf_state = not not rf_control.rf_state
					table.insert(capabilities.rf_controls, cap)
				end
			end
			if info.antenna_controls then
				capabilities.antenna_controls = {}
				for _, antenna_control in pairs(info.antenna_controls) do
					for _, antenna in pairs(antenna_control.antenna) do
						table.insert(capabilities.antenna_controls, { linked_device = antenna_control.linked_device, detector_type = antenna.detector_type, name = antenna.name })
					end
				end
			end
			if info.sim_hotswap then
				capabilities.sim_hotswap = info.sim_hotswap
			end
			if info.voice then
				capabilities.voice = info.voice
			end
			if info.network_interfaces then
				capabilities.network_interfaces = info.network_interfaces
			end
		end
	end
	return capabilities
end

local function ubus_get_capabilities(req)
	runtime.ubus:reply(req, M.get_capabilities())
end

local function ubus_get_info(req)
	local info = {}
	if plugin then
		local platform_info = plugin.get_platform_capabilities()
		if platform_info then
			if platform_info.power_controls then
				for _, power_control in pairs(platform_info.power_controls) do
					if power_control.power_state then
						if not info.power_controls then
							info.power_controls = {}
						end
						table.insert(info.power_controls, { linked_device = power_control.linked_device, power_state = power_control.power_state() })
					end
				end
			end
			if platform_info.rf_controls then
				for _, rf_control in pairs(platform_info.rf_controls) do
					if rf_control.rf_state then
						if not info.rf_controls then
							info.rf_controls = {}
						end
						table.insert(info.rf_controls, { linked_device = rf_control.linked_device, rf_state = rf_control.rf_state() })
					end
				end
			end
			if platform_info.antenna_controls then
				for _, antenna_control in pairs(platform_info.antenna_controls) do
					if antenna_control.antenna then
						for _, antenna in pairs(antenna_control.antenna) do
							local antenna_info = {
								linked_device = antenna_control.linked_device,
								current_antenna = antenna.antenna_state(),
								name = antenna.name,
								auto_selected_antenna = antenna.auto_selected_antenna
							}
							if antenna.external_detected then
								antenna_info.external_detected = antenna.external_detected()
							end
							if not info.antenna_controls then
								info.antenna_controls = {}
							end
							table.insert(info.antenna_controls, antenna_info)
						end
					end
				end
			end
		end
	end
	runtime.ubus:reply(req, info)
end

function M.get_ubus_methods()
	local ubus_methods = {
		['mobiled.platform'] = {
			capabilities = { ubus_get_capabilities, {} },
			get = { ubus_get_info, {} }
		}
	}
	return ubus_methods
end

function M.init(rt)
	runtime = rt
	local status, m = pcall(require, "libplatform")
	if status and m then
		plugin = m
		if plugin.init then
			plugin.init()
		end
	end
end

return M
