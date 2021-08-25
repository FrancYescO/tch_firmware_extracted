local M = {}

function M.entry(runtime)
	runtime.ubus:call("network.interface.wan", "down", {})
	runtime.ubus:call("network.interface.wan6", "down", {})

	return true
end

function M.exit(runtime, l2type)
	runtime.ubus:call("network.interface.wan", "up", {})
	runtime.ubus:call("network.interface.wan6", "up", {})

	return true
end

return M
