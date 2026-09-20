---------------------------------
--! @file
--! @brief The platform module giving access to platform specific methods
---------------------------------

local pairs = pairs
local runtime, plugin

local M = {}

function M.get_capabilities()
	if plugin then
		return plugin.get_platform_capabilities()
	end
	return {}
end

function M.get_linked_antenna_controls(device)
	local controls = {}
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.antenna_controls then
			for _, antenna_control in pairs(info.antenna_controls) do
				if antenna_control.linked_device.dev_desc == device.desc then
					table.insert(controls, antenna_control)
				end
			end
		end
	end
	return controls
end

function M.get_linked_power_control(device)
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.power_controls then
			for _, power_control in pairs(info.power_controls) do
				if power_control.linked_device.dev_desc == device.desc then
					return power_control
				end
			end
		end
	end
end

function M.sim_hotswap_supported(device)
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.sim_hotswap then
			for _, sim_hotswap in pairs(info.sim_hotswap) do
				if sim_hotswap.linked_device.dev_desc == device.desc then
					return true
				end
			end
		end
	end
	return false
end

function M.power_all_on()
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.power_controls then
			for _, power_control in pairs(info.power_controls) do
				if power_control.power_on then
					power_control.power_on()
				end
			end
		end
	end
end

function M.power_all_off()
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.power_controls then
			for _, power_control in pairs(info.power_controls) do
				if power_control.power_off then
					power_control.power_off()
				end
			end
		end
	end
end

function M.reset_all()
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.power_controls then
			for _, power_control in pairs(info.power_controls) do
				if power_control.reset then
					power_control.reset()
				end
			end
		end
	end
end

function M.get_capabilities()
	local capabilities = {}
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info then
			if info.power_controls then
				capabilities.power_controls = {}
				for _, power_control in pairs(info.power_controls) do
					local cap = { linked_device = power_control.linked_device, id = power_control.id, power_on = false, power_off = false, reset = false, power_state = false }
					cap.power_on = not not power_control.power_on
					cap.power_off = not not power_control.power_off
					cap.reset = not not power_control.reset
					cap.power_state = not not power_control.power_state
					table.insert(capabilities.power_controls, cap)
				end
			end
			if info.antenna_controls then
				capabilities.antenna_controls = {}
				for _, antenna_control in pairs(info.antenna_controls) do
					table.insert(capabilities.antenna_controls, { linked_device = antenna_control.linked_device, detector_type = antenna_control.detector_type, id = antenna_control.id, name = antenna_control.name })
				end
			end
			if info.sim_hotswap then
				capabilities.sim_hotswap = info.sim_hotswap
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
		if platform_info and platform_info.power_controls then
			info.power_controls = {}
			for _, power_control in pairs(platform_info.power_controls) do
				local power_state = "unknown"
				if power_control.power_state then
					power_state = power_control.power_state()
				end
				table.insert(info.power_controls, { current_power_state = power_state, id = power_control.id })
			end
		end
		if platform_info and platform_info.antenna_controls then
			info.antenna_controls = {}
			for _, antenna_control in pairs(platform_info.antenna_controls) do
				local antenna_info = {
					current_antenna = antenna_control.antenna_state(),
					id = antenna_control.id,
					auto_selected_antenna = antenna_control.auto_selected_antenna
				}
				if antenna_control.external_detected then
					antenna_info.external_detected = antenna_control.external_detected()
				end
				table.insert(info.antenna_controls, antenna_info)
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
