local M = {}
local uci = require("uci")

function M.entry(runtime)
	local x = uci.cursor()
	x:foreach("mobiled", "device", function(s)
		if s.imei then
			runtime.log:notice("Reset device enabled to 1 for " .. s.imei)
			runtime.config.set_device_enable({info = {imei = s.imei, device_config_parameter = "imei"}}, "1")
		end
	end)
	return true
end

return M
