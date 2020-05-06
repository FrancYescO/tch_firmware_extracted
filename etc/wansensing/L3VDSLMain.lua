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
	'network_interface_wan_ifdown',
	'network_interface_wantag_ifup',
	'network_interface_wantag_ifdown',
} 
local xdslctl = require('transformer.shared.xdslctl')

local match = string.match
---
-- Main function called if a wansensing L3 state is checked.
--
-- @function [parent=M] 
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @param #3 specifies the event which triggered this check method call (eg. timeout, network_device_atm_8_35_up)
-- @return #1 string specifying the next wansensing state
function M.check(runtime, l2type, event)
    local scripthelpers = runtime.scripth
    local conn = runtime.ubus
    local logger = runtime.logger
    local uci = runtime.uci
    logger:notice("WAN Sensing L3 Checking")
    if not uci then
        return false
    end
    local x = uci.cursor()
   
    
	local current = x:get("wansensing", "global", "l2type")
	logger:notice("Current Mode " .. current)
	local mode = xdslctl.infoValue("tpstc") 
	-- check if wan ethernet port is up
	
	if (not match(mode, "ATM")) and (not match(mode, "PTM")) and (not scripthelpers.l2HasCarrier("eth4")) then
		logger:notice("Changing to L2 Sense")
		return "L2Sense"   
	elseif scripthelpers.l2HasCarrier("eth4") and current ~= "ETH" then
		logger:notice("Changing to ETH From " .. current)
		return "L2Sense"
	else

		if mode then
			if match(mode, "ATM") and current ~= "ADSL" then
				 logger:notice("Changing to ADSL From " .. current)
				 return "L2Sense"
			elseif match(mode, "PTM") and current ~= "VDSL" then
				 logger:notice("Changing to VDSL From " .. current)
				 return "L2Sense"
		  end
		end
	end 
	local cwmpd = x:get("cwmpd", "cwmpd_config", "state")
	if cwmpd ~= "1" then
		local wan_if=x:get("env", "custovar", "wan_if") 
		local wan_tag=x:get("env", "custovar", "wan_tag")
		local tag,iface = nil, nil
		if scripthelpers.checkIfInterfaceHasIP(wan_if) then
			logger:notice("Setting Untagged VDSL")
			tag = "0"
			iface = "ptm0"
		elseif scripthelpers.checkIfInterfaceHasIP("wantag") then
			logger:notice("Setting Tagged VDSL")
			tag = "1"
			iface = "vlan_ptm0"
		end
		if tag then
			if tag ~= wan_tag then
				x:set("network", wan_if, "ifname", iface)
			end
			x:set("network", "wantag", "auto", "0")
			x:commit("network")
			conn:call("network", "reload", { })
			x:set("cwmpd", "cwmpd_config", "state", "1")
			x:commit("cwmpd")
			os.execute("/etc/init.d/cwmpd reload")
		end
	end
   

   return "L3VDSLSense"
end

return M


