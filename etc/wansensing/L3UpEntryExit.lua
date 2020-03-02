---
-- Module L3 EntryExit.
-- Module Specifies the entry and exit functions of a L3 wansensing state
-- @module modulename
local M = {}

---
-- Entry function called if a wansensing L3 state is entered.
--
-- @function [parent=M]
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @return #1 boolean indicates if the entry actions are executed/not executed
function M.entry(runtime, l2type)
    local scripthelpers = runtime.scripth
    local uci = runtime.uci
    local conn = runtime.ubus

    if not uci or not conn then
      return false
    end
    local logger = runtime.logger
    local x = uci.cursor()
    logger:notice("WAN Sensing Disabling Mobile interface")
    x:set("network", "wwan", "auto", "0")
    x:commit("network")
    conn:call("network.interface.wwan", "down", { })

    x:set("cwmpd", "cwmpd_config", "interface", "wan")
    x:commit("cwmpd")
    os.execute("/etc/init.d/cwmpd reload")
    return true
end

---
-- Entry function called if a wansensing L3 state is entered.
--
---
-- Exit function called if a wansensing L3 state is exited.
--
-- @function [parent=M]
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @param #3 string specifying the next state
-- @return #1 boolean indicates if the exit actions are executed/not executed
function M.exit(runtime, l2type, transition)
   local scripthelpers = runtime.scripth
   local uci = runtime.uci
   local conn = runtime.ubus

   if not uci or not conn then
      return false
   end
   local logger = runtime.logger
   local x = uci.cursor()
   logger:notice("WAN Sensing Enabling Mobile interface")
   x:set("network", "wwan", "auto", "1")
   x:commit("network")
   conn:call("network.interface.wwan", "up", { })

   x:set("cwmpd", "cwmpd_config", "interface", "wwan")
   x:commit("cwmpd")
   os.execute("/etc/init.d/cwmpd reload")
   return true
end

return M

