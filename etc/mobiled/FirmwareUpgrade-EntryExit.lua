local M = {}

function M.entry(runtime, dev_idx)
	local log = runtime.log
	local mobiled = runtime.mobiled

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return nil, "No such device"
	end
	if device.info.firmware_upgrade.path then
		if device:firmware_upgrade(device.info.firmware_upgrade.path) then
			device.info.firmware_upgrade.status = "running"
			local state_data = device.sm:get_state_data()
			local config = mobiled.get_device_config(device)
			log:info("Setting firmware upgrade timeout to %d seconds", config.device.firmware_upgrade_timeout)
			state_data.firmware_upgrade_timer = { value = config.device.firmware_upgrade_timeout, timer = runtime.uloop.timer(function()
				log:error("Timeout in FirmwareUpgrade after %d seconds", state_data.firmware_upgrade_timer.value)
				state_data.firmware_upgrade_timer = nil
				device.info.firmware_upgrade.status = "timeout"
				runtime.events.send_event("mobiled", { event = "firmware_upgrade_failed", dev_idx = dev_idx })
			end, config.device.firmware_upgrade_timeout * 1000) }
			return true
		else
			return nil, "Failed to start firmware upgrade"
		end
	end
	return nil, "Missing firmware upgrade path"
end

function M.exit(runtime, _, dev_idx)
	local device = runtime.mobiled.get_device(dev_idx)
	if device then
		device.info.firmware_upgrade.status = "not_running"
		device.info.firmware_upgrade.path = nil
		local state_data = device.sm:get_state_data()
		if state_data.firmware_upgrade_timer then
			state_data.firmware_upgrade_timer.timer:cancel()
			state_data.firmware_upgrade_timer = nil
		end
	end
	return true
end

return M
