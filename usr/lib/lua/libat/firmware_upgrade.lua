local uci = require("uci")

local M = {}

function M.update_state(device, info)
	local c = uci.cursor(nil, "/var/state")
	c:revert("mobiled")
	c:set("mobiled", "firmware_upgrade", "firmware_upgrade")
	if info.target_version then
		c:set("mobiled", "firmware_upgrade", "target_version", info.target_version)
	end
	if info.status then
		c:set("mobiled", "firmware_upgrade", "status", info.status)
	end
	if info.error_code then
		c:set("mobiled", "firmware_upgrade", "error_code", info.error_code)
	end
	c:save("mobiled")
	device:send_event("mobiled.firmware_upgrade", { status = info.status, dev_idx = device.dev_idx, target_version = info.target_version, error_code = info.error_code })
end

function M.get_state()
	local c = uci.cursor(nil, "/var/state")
	local info = {}
	info.target_version = c:get("mobiled", "firmware_upgrade", "target_version")
	info.error_code = c:get("mobiled", "firmware_upgrade", "error_code")
	info.status = c:get("mobiled", "firmware_upgrade", "status")
	if not info.status then return nil end
	return info
end

function M.reset_state()
	local c = uci.cursor(nil, "/var/state")
	c:revert("mobiled")
end

return M
