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
--M.SenseEventSet = { "network_interface_wan_ifup", "network_interface_wan_ifdown" , "network_device_pppoa-wan_up" , "network_device_pppoa-wan_down" , "network_device_ptm0_up" , "network_device_ptm0_down", "network_device_eth4_up" , "network_device_eth4_down", "xdsl_1", "xdsl_2", "xdsl_3", "xdsl_4", "xdsl_5", "xdsl_6"}
 

local xdslctl = require('transformer.shared.xdslctl')

local match = string.match

---
-- Main function called if a wansensing L2 state is checked.
--
-- @function [parent=M] 
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 specifies the event which triggered this check method call (eg. timeout, network_device_atm_8_35_up)
-- @return #1 string specifying the next wansensing state
-- @return #2 string specifying the sensed layer 2 type, this string is passed as input parameter in the L2 Exit function and L3 function API
function M.check(runtime)
    local scripthelpers = runtime.scripth
    local uci = runtime.uci
    if not uci then
        return false
    end
    local x = uci.cursor()
    local SETUP =x:get("env", "var", "setup")
    local WS =x:get("env", "var", "WS")
    -- check if wan Ethernet port is up
      
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

     return "L2Sense"     
end

return M
