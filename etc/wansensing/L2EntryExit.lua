---
-- Module L2 EntryExit.
-- Module Specifies the entry and exit functions of a L2 wansensing state
-- @module modulename
local M = {}
local proxy = require("datamodel")
---
-- Entry function called if a wansensing L2 state is entered.
--
-- @function [parent=M] 
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @return #1 boolean indicates if the entry actions are executed/not executed
function M.entry(runtime)
   return true
end

---
-- Exit function called if a wansensing L2 state is exited.
--
-- @function [parent=M] 
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @param #3 string specifying the next state
-- @return #1 boolean indicates if the exit actions are executed/not executed
function M.exit(runtime, l2type, transition)
   local uci = runtime.uci
   local scripthelpers = runtime.scripth
   local conn = runtime.ubus
   local format = string.format
   local logger = runtime.logger

   local x = uci.cursor()
   local prevL2 = x:get("wansensing", "global", "l2type")
   -- reconfiguration of lower layer not needed if sensed l2type is not changed
   -- voice service + mwan reconfiguration is done in the entry scripts of L3SingleWan and L3Multiwan
  -- if prevL2 == l2type then
  --    return true
  -- end
   
   -- reconfigure if sensed l2type changed
   logger:notice("Configuring the lower layer interfaces of the network stack using l2type " .. l2type)
   
	
	  
   if l2type == "ETH" then
      --1 interface to route the data service
      --1 interface to route the voip service      
      logger:notice("ETH WAN Setup - Set to ETH")
      x:set("network", "wan", "auto", "1")
	 logger:notice("ETH WAN Setup: Rewrite the user/pass of the dummy pppoe and pppoa")
   local user_ppp = x:get("network", "wan", "username")
   local pass_ppp = x:get("network", "wan", "password")
   x:set("network", "wanpppoa", "auto", "0")
   x:set("network", "wanpppoa", "username", user_ppp)
   x:set("network", "wanpppoa", "password", pass_ppp)
   x:set("network", "wanpppoe", "auto", "0")
   x:set("network", "wanpppoe", "username", user_ppp)
   x:set("network", "wanpppoe", "password", pass_ppp)
   	logger:notice("ETH WAN Setup - Set to ptm0 the voice lower layer")
   x:set("network", "wan", "ifname", "waneth4")
   x:set("network", "wan", "proto", "pppoe")
	x:set("network", "broadif1", "ifname", "voipeth4")
    x:set("network", "broadif1", "auto", "1")
            
   elseif l2type == "VDSL" then
      logger:notice("Setup - Set to VDSL")
   x:set("network", "wan", "auto", "1")
   local user_ppp = x:get("network", "wan", "username")
   local pass_ppp = x:get("network", "wan", "password")
   x:set("network", "wanpppoa", "auto", "0")
   	logger:notice("VDSL: Rewrite the user/pass of the dummy pppoe and pppoa")
   x:set("network", "wanpppoa", "username", user_ppp)
   x:set("network", "wanpppoa", "password", pass_ppp)
   x:set("network", "wanpppoe", "auto", "0")
   x:set("network", "wanpppoe", "username", user_ppp)
   x:set("network", "wanpppoe", "password", pass_ppp)
	   logger:notice("VDSL Setup - Set to ptm0 the lower layer")
      x:set("network", "wan", "ifname", "wanptm0")
	   logger:notice("Setup - Set to proto pppoe")
	   x:set("network", "wan", "proto", "pppoe")
	   logger:notice("VDSL Setup - Set to ptm0 the voice lower layer")
      x:set("network", "broadif1", "ifname", "voipptm0") 
    
   elseif l2type == "ADSL" then
      --1 interface to route the data service
      --1 interface to route the voip service (depends on the location but let's configure)      
	logger:notice("ADSL Setup - Set to auto 0 wan interface and disconnect all active PPP connection")
	x:set("network", "wan", "auto", "0")
	local user_ppp = x:get("network", "wan", "username")
	local pass_ppp = x:get("network", "wan", "password")
	logger:notice("ADSL: Rewrite the user/pass of the dummy pppoe and pppoa")
	x:set("network", "wanpppoa", "username", user_ppp)
	x:set("network", "wanpppoa", "password", pass_ppp)
	x:set("network", "wanpppoe", "username", user_ppp)
	x:set("network", "wanpppoe", "password", pass_ppp)
--	x:commit("network")
--	logger:notice("L2 sense : Wait 5 seconds before reload network to avoid crash from PPPoA to PPPoE")
--	os.execute("sleep 5")
--	logger:notice("L2 sense : reload network")
--	os.execute("/etc/init.d/network reload")
	logger:notice("ADSL Setup - Set to AUTO 1 WAN dummy interfaces")
	x:set("network", "wanpppoa", "auto", "1")
	x:set("network", "wanpppoe", "auto", "1")
--	os.execute("ifup wanpppoa")
--	os.execute("ifup wanpppoe")
	x:set("network", "broadif1", "ifname", "atm_9_35")
    x:set("network", "broadif1", "auto", "1")
   
   end

	x:commit("network")
	os.execute("/etc/init.d/network reload")
	os.execute("ifup broadif1")

	
  
   return true 
end

return M
