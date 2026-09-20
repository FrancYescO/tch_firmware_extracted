local M = {}

function M.entry(runtime, dev_idx)
	local log = runtime.log
	local mobiled = runtime.mobiled

	log:notice("WaitingForDevice-> Entry Function")

	local config = mobiled.get_config()
	if config.platform and config.platform.power_on then
		if mobiled.platform and mobiled.platform.module_power_on then
			mobiled.platform.module_power_on()
		end
	else
		if mobiled.platform and mobiled.platform.module_power_off then
			mobiled.platform.module_power_off()
		end
	end
	return true
end

function M.exit(runtime, dev_idx)
	local log = runtime.log
	log:notice("WaitingForDevice-> Exit Function")
	return true
end

return M
