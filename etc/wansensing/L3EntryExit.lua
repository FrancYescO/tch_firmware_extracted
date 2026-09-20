local M = {}

function M.entry(runtime)

	local scripthelpers = runtime.scripth
	local uci = runtime.uci
	local logger = runtime.logger
	local x = uci.cursor()

	--Reconfigure IPv6 on 'wan' in function of 6rd availability
	logger:notice("Check/Change IPv6 Deployment")
	if runtime.scripth.checkIfInterfaceIsUp("6rd") then
		x:set("network", "wan6", "auto", "0")
		scripthelpers.set_state(uci,"ipv6Deployment", "6RD")
		logger:notice("Convert factory defaults to use 6RD")
	else
		x:set("network", "wan6", "auto", "1")
		scripthelpers.set_state(uci,"ipv6Deployment", "DualStack")
		logger:notice("Convert factory defaults to use DualStack")
	end

	x:commit("network")
	os.execute("/etc/init.d/network reload")

	return true
end

function M.exit(runtime, l2type)
	-- nothing to do
	return true
end

return M
