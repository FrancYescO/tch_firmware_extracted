local conn = require('ubus').connect()

local M = {}

function M.process(notifier, action, event)
	if event == "limit_reached" or event == "threshold_reached" then
		if action.numbers and action.message then
			local data = conn:call("mobiled", "devices", {})
			if not data or data.error then
				return nil, "Failed to retrieve mobile device info"
			end
			for _, mobile_device in pairs(data.devices) do
				data = conn:call("mobiled.device", "capabilities", {dev_idx = mobile_device.dev_idx})
				if not data or data.error then
					return nil, "Failed to verify SMS support"
				end
				if data.sms_sending == true then
					for _, number in pairs(action.numbers) do
						notifier.log:info("Sending SMS to %s", number)
						data = conn:call("mobiled.sms", "send", {dev_idx = mobile_device.dev_idx, number = number, message = action.message})
						if data and data.error then
							return nil, "Failed to send SMS"
						end
					end
					break
				else
					notifier.log:warning("SMS not supported")
				end
			end
		else
			return nil, "Missing UCI config"
		end
	end
	return true
end

return M