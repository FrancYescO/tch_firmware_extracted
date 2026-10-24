local M = {}

function M.entry(runtime, dev_idx)
	local log = runtime.log
	local mobiled = runtime.mobiled
	log:notice("FirmwareUpgrade-> Entry Function")
	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return nil, "No such device"
	end
	if device.info.firmware_upgrade.path then
		device.info.firmware_upgrade.status = "running"
		return device:firmware_upgrade(device.info.firmware_upgrade.path)
	end
end

function M.exit(runtime, transition, dev_idx)
	local log = runtime.log
	local mobiled = runtime.mobiled
	log:notice("FirmwareUpgrade-> Exit Function")
	local device = mobiled.get_device(dev_idx)
	if device then
		log:notice("FirmwareUpgrade-> Clearing info")
		device.info.firmware_upgrade.status = "not_running"
		device.info.firmware_upgrade.path = nil
	end
	return true
end

return M
