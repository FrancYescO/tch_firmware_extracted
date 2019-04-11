local uci = require("uci")

local M = {
	error_codes = {
		no_error = 0,
		unknown_error = 1,
		not_supported = 2,
		invalid_state = 3,
		download_failed = 4,
		invalid_image = 5,
		flashing_failed = 6
	}
}

function M.update_state(device, info)
	local c = uci.cursor()
	c:delete("mobiled_firmware_upgrade_state", "firmware_upgrade")
	c:set("mobiled_firmware_upgrade_state", "firmware_upgrade", "firmware_upgrade")
	if info.target_version then
		c:set("mobiled_firmware_upgrade_state", "firmware_upgrade", "target_version", info.target_version)
	end
	if info.status then
		c:set("mobiled_firmware_upgrade_state", "firmware_upgrade", "status", info.status)
	end
	if info.error_code then
		c:set("mobiled_firmware_upgrade_state", "firmware_upgrade", "error_code", info.error_code)
	end
	if info.device_error then
		c:set("mobiled_firmware_upgrade_state", "firmware_upgrade", "device_error", info.device_error)
	end
	if info.old_version then
		c:set("mobiled_firmware_upgrade_state", "firmware_upgrade", "old_version", info.old_version)
	end
	c:commit("mobiled_firmware_upgrade_state")
	device:send_event("mobiled.firmware_upgrade", { status = info.status, dev_idx = device.dev_idx, target_version = info.target_version, error_code = info.error_code, device_error = info.device_error, old_version = info.old_version })
end

function M.get_state()
	local c = uci.cursor()
	local info = {}
	info.target_version = c:get("mobiled_firmware_upgrade_state", "firmware_upgrade", "target_version")
	info.error_code = c:get("mobiled_firmware_upgrade_state", "firmware_upgrade", "error_code")
	info.status = c:get("mobiled_firmware_upgrade_state", "firmware_upgrade", "status")
	info.device_error = c:get("mobiled_firmware_upgrade_state", "firmware_upgrade", "device_error")
	info.old_version = c:get("mobiled_firmware_upgrade_state", "firmware_upgrade", "old_version")
	if not info.status then return nil end
	return info
end

function M.reset_state()
	local c = uci.cursor()
	c:delete("mobiled_firmware_upgrade_state", "firmware_upgrade")
end

return M
