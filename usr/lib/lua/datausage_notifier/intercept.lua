local uci = require("uci")

local M = {}

function M.process(notifier, action, event)
	local ignore = action.ignore == '1' or action.ignore == 'true' or action.ignore == true
	if event == "limit_reached" or event == "threshold_reached" then
		if not ignore then
			local _, error = notifier.ubus:call("intercept", "add_reason", { reason = "datausage_" .. event, persist = true })
			if error then
				return nil, "Failed to enable intercept"
			end
		else
			notifier.log:info("[%s] Ignoring %s event", action['.name'], event)
		end
		return true
	elseif event == "reset" or event == "ignore_limit" or event == "ignore_threshold" then
		local cursor = uci.cursor()
		if event == "reset" then
			cursor:delete(notifier.config_file, action['.name'], 'ignore')
			action.ignore = false
		elseif event == "ignore_limit" or event == "ignore_threshold" then
			cursor:set(notifier.config_file, action['.name'], 'ignore', '1')
			action.ignore = true
		end
		cursor:commit(notifier.config_file)
		cursor:close()

		notifier.log:info("Disabling data usage intercept")
		local _, error = notifier.ubus:call("intercept", "del_reason", { reason = "datausage_limit_reached" })
		if error then
			return nil, "Failed to disable intercept"
		end
		_, error = notifier.ubus:call("intercept", "del_reason", { reason = "datausage_threshold_reached" })
		if error then
			return nil, "Failed to disable intercept"
		end
		return true
	end
	return nil, "Unknown event"
end

return M
