---
-- Module L2 Main.
-- Module Specifies the check functions of a wansensing state
-- @module modulename
local M = {}
---
-- List all events with will schedule the check method
--   Support implemented for :
--       a) network interface state changes coded as `network_interface_xxx_yyy` (xxx= OpenWRT interface name, yyy = ifup/ifdown)
--       b) dslevents (xdsl_1(=idle)/xdsl_2/xdsl_3/xdsl_4/xdsl_5(=show time))
--       c) network device state changes coded as 'network_device_xxx_yyy' (xxx = linux netdev, yyy = up/down)
-- @SenseEventSet [parent=#M] #table SenseEventSet
M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wan_ifup', 
    'network_interface_wan_ifdown' ,
}
local xdslctl = require('transformer.shared.xdslctl')
local match = string.match

function M.check(runtime)
	local scripthelpers = runtime.scripth
	local conn = runtime.ubus
	local logger = runtime.logger
	local uci = runtime.uci

	if not uci then
		return false
	end
   local x = uci.cursor()
	-- check if wan ethernet port is up
	if scripthelpers.l2HasCarrier("eth4") then
		return "L3Sense", "ETH"
	else
		-- check if xDSL is up
		local mode = xdslctl.infoValue("tpstc")
		if mode then
			if match(mode, "ATM") then
			    return "L3Sense", "ADSL"
			elseif match(mode, "PTM") then
			    return "L3Sense", "VDSL"
			end
		end
	end
	--DR Section to check if wwan is enabled and if not enable it (covered config errors) 
   local mobile = x:get("network", "wwan", "auto")
	logger:notice("WAN Sensing Mobile: "..mobile)
    
	if mobile == "0" then 
		 logger:notice("WAN Sensing - Enabling Mobile interface")
		 x:set("network", "wwan", "auto", "1")
		 x:commit("network")
		 conn:call("network.interface.wwan", "up", { })
	end
	return "L2Sense"
end

return M
