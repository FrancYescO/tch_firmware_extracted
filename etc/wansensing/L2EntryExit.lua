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
  
  -- bring down the data interface
  conn:call("network.interface.wan", "down", { })
  
   
  
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

     conn:call("network", "reload", { })
     
     local vlan = x:get("env", "custovar", "wan_vlan")
     if not vlan then 
        local default_vlan = x:get("env", "custovar", "wan_vlan_default")
        vlan = default_vlan
     end   
  
     if l2type == "ETH" then
        local mtu = x:get("env", "custovar", "mtu_eth")
        local l2_mtu = tostring(tonumber(mtu)+8)
        x:set("network", "wan", "ifname", "eth4")
        x:set("network", "wan", "proto", "pppoe")
        x:set("network", "wan", "authfail", "0")
        x:set("network", "wan", "mtu", mtu)
        x:set("network", "vlan_wan", "mtu", l2_mtu)
        x:set("network", "eth4", "mtu", l2_mtu)
        x:set("network", "bt_iptv", "auto", "0")
        x:set("env", "custovar", "wan_vlan_enabled", "0")
        x:set("env", "custovar", "setup", "ETH")
        x:set("ethoam", "global", "enable", "0")
        logger:notice("Setup - Set to ETH in ENV")
     elseif l2type == "VDSL" then
        local mtu = x:get("env", "custovar", "mtu_vdsl")
        local l2_mtu = tostring(tonumber(mtu)+8)
        x:set("network", "wan", "ifname", "vlan_wan")
        x:set("network", "vlan_wan", "vid", vlan)
        x:set("network", "wan", "proto", "pppoe")
        x:set("network", "wan", "authfail", "0")
        x:set("network", "vlan_wan", "ifname", "ptm0")
        x:set("network", "wan", "mtu", mtu)
        x:set("network", "vlan_wan", "mtu", l2_mtu)
        x:set("network", "ptm0", "mtu", l2_mtu)
        x:set("env", "custovar", "wan_vlan", vlan)
        x:set("env", "custovar", "wan_vlan_enabled", "1")
        x:set("env", "custovar", "setup", "VDSL")
        x:set("network", "bt_iptv", "auto", "1")
        x:set("ethoam", "config1", "ifname", "vlan_wan")
        x:set("ethoam", "config2", "ifname", "vlan_wan")
        x:set("ethoam", "config3", "ifname", "ptm0")
        x:set("ethoam", "global", "enable", "1")
        logger:notice("Setup - Set to VDSL in ENV")
     elseif l2type == "ADSL" then
        local mtu = x:get("env", "custovar", "mtu_adsl")
        local vci = x:get("env", "custovar", "vci")   
        local vpi = x:get("env", "custovar", "vpi")
        local enc = x:get("env", "custovar", "enc")   
        local ulp = x:get("env", "custovar", "ulp")
        x:set("network", "wan", "ifname", "atm0")
        x:set("network", "wan", "proto", "pppoa")
        x:set("network", "wan", "vpi", vpi)
        x:set("network", "wan", "vci", vci)
        --Only set the MTU if larger then 1500 for ADSL
        if tonumber(mtu) > 1500  then 
            mtu= "1500"
        end
        x:set("network", "wan", "mtu", mtu)
        x:set("xtm", "atm0", "vpi", vpi)
        x:set("xtm", "atm0", "vci", vci)
        x:set("xtm", "atm0", "enc", enc)
        x:set("xtm", "atm0", "ulp", ulp)
        x:commit("xtm")
        x:set("network", "wan", "authfail", "0")
        x:set("env", "custovar", "setup", "ADSL")
        x:set("network", "bt_iptv", "auto", "0")
        x:set("ethoam", "global", "enable", "0")
        logger:notice("Setup - Set to ADSL in ENV")
     end
     x:set("network", "wan", "auto", "1")
     if x:get("env", "custovar", "WS") == "0" then 
        x:set("env", "custovar", "WS", "1")
     end
     x:commit("ethoam")
     x:commit("network")
     x:commit("env")
     conn:call("network", "reload", { })
     conn:call("network.interface.wan", "up", { })
     os.execute("/etc/init.d/ethoam reload")  
     --Reenable the CWMPd if the env var is set
     local cwmpd_enabled = x:get("env", "custovar", "cwmpd_enabled")  
     x:set("cwmpd", "cwmpd_config", "state", cwmpd_enabled)
     x:commit("cwmpd") 
     os.execute("/etc/init.d/cwmpd reload") 

   return true
end

return M
