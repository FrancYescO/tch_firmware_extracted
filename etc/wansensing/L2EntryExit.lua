---
-- Module L2 EntryExit.
-- Module Specifies the entry and exit functions of a L2 wansensing state
-- @module modulename
local M = {}

---
-- Entry function called if a wansensing L2 state is entered.
--
-- @function [parent=M] 
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @return #1 boolean indicates if the entry actions are executed/not executed
function M.entry(runtime)

   local uci = runtime.uci
   local conn = runtime.ubus

   if not uci or not conn then
      return false
   end

   local x = uci.cursor()

	x:set("network", "wan", "auto", "0")

	x:commit("network")
	conn:call("network", "reload", { })
   --conn:call("network.interface.wan", "down", { })

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
   local conn = runtime.ubus
   local format = string.format
   local logger = runtime.logger
   if not uci or not conn then
      return false
   end

   local x = uci.cursor()
	 



	 if l2type == "ETH" then
		x:set("network", "wan", "ifname", "eth4")
		logger:notice("Setup - Set to ETH")
	 elseif l2type == "VDSL" then
		x:set("network", "wan", "ifname", "ptm0")
		logger:notice("Setup - Set to VDSL")
	 elseif l2type == "ADSL" then
		x:set("network", "wan", "ifname", "atm0")
		logger:notice("Setup - Set to ADSL")
	 end
	x:commit("network")
   conn:call("network", "reload", { })
    
   -- conn:call("network.interface." .. tostring(interface), "up", { })
	 
    if l2type ~= "ETH" then
      os.execute("/etc/init.d/xtm reload")
    end
    x:set("network", "wan", "auto", "1")
    x:commit("network")
    conn:call("network", "reload", { })
	 
   return true
end

return M
