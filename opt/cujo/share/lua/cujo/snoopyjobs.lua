--
-- This file is Confidential Information of Cujo LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

cujo.jobs.spawn("ipv6-watchdog", function ()
	while true do
		local wan_ipv6addr = cujo.snoopy.getdevaddripv6(cujo.config.lan_ifaces)
		if cujo.config.wan_ipv6addr ~= wan_ipv6addr then
			cujo.log:warn('Detected new IPv6 address ', wan_ipv6addr, ', reconnecting')
			cujo.cloud.disconnect()
			cujo.config.wan_ipv6addr = wan_ipv6addr
			cujo.cloud.connect()
		end
		time.sleep(5)
	end
end)
