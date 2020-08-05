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
  local uci = runtime.uci
  local conn = runtime.ubus
  
  if not uci or not conn then
      return false
  end
  
  local x = uci.cursor()
  
  x:set("network", "vdsl_check", "username", x:get("network", "wan", "username") or "")
  x:set("network", "vdsl_check", "password", x:get("network", "wan", "password") or "")
  x:set("network", "vdsl_check", "auto", "1")
  x:commit("network")
  conn:call("network.interface.vdsl_check", "up", { })
  return true
end

---
-- Exit function called if a wansensing L3 state is exited.
--
-- @function [parent=M]
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @param #3 string specifying the next state
-- @return #1 boolean indicates if the exit actions are executed/not executed
function M.exit(runtime, l2type, transition)
  local logger = runtime.logger
  local scripthelpers = runtime.scripth
  local uci = runtime.uci
  local conn = runtime.ubus
  
  if not uci or not conn or not scripthelpers or not logger then
      return false
  end
  
  local x = uci.cursor()

  if scripthelpers.checkIfInterfaceIsUp("vdsl_check") then
      x:set("network", "vdsl_check", "auto", "0")
      x:set("network", "wan", "ifname", "ptm0")
      x:commit("network")
      conn:call("network", "reload", { })
      conn:call("network.interface.wan", "up", { })
      conn:call("network.interface.vdsl_check", "down", { })
      x:set("env", "custovar", "wan_vlan_enabled", "0")
      x:commit("env")
      x:set("ethoam", "global", "enable", "0")
      x:commit("ethoam")
      os.execute("/etc/init.d/ethoam reload")
      logger:notice("Setup - Set to VDSL to Untagged")
  else
      x:set("network", "vdsl_check", "auto", "0")
      x:commit("network")
      conn:call("network", "reload", { })
      conn:call("network.interface.vdsl_check", "down", { })
  end
  
                  
  return true
end

return M

