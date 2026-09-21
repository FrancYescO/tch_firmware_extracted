local M = {}

function M.process(notifier)
	notifier.log:info("Sending e-mail")
	return true
end

return M