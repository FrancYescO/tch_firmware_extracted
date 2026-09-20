package.path = "/etc/wansensing/lib/?.lua;" .. package.path
local myhelpers = require("Scenario")

local M = {}
--[[************* COPYRIGHT AND CONFIDENTIALITY INFORMATION ***************
--** Copyright © 2014 - 2016 TECHNICOLOR DELIVERY TECHNOLOGIES, SAS       **
--** - All Rights Reserved                                                **
--** Technicolor hereby informs you that certain portions                 **
--** of this software module and/or Work are owned by Technicolor         **
--** and/or its software providers.                                       **
--** Distribution copying and modification of all such work are reserved  **
--** to Technicolor and/or its affiliates, and are not permitted without  **
--** express written authorization from Technicolor.                      **
--** Technicolor is registered trademark and trade name of Technicolor,   **
--** and shall not be used in any manner without express written          **
--** authorization from Technicolor                                       **
--*************************************************************************
--]]

local CurrentScenarioName="ADSL_wholesales" -- should match with ./lib/scenario.lua

local function existInterface(x,runtime,name)
   return myhelpers.existInterfaceCommon(x,runtime,name,CurrentScenarioName)
end

--Map between interface name and scenario name
local ScenarioMAP = myhelpers.ScenarioMAP
local InterfaceMAP = myhelpers.InterfaceMAP

function M.entry(runtime, l2type)
   local scripthelpers = runtime.scripth
   local conn = runtime.ubus
   local uci = runtime.uci
   local x = uci.cursor()
   local turnAutoOnOff = myhelpers.turnAutoOnOff

   -- Copy the interface settings to the WAN:
   if existInterface(x,runtime,"wan") then
      --remove dummy if it already existed (copy_interface would only merge otherwise)
         scripthelpers.delete_interface("dummy")
      --Make a copy of "network.wan" to "network.dummy"
         scripthelpers.copy_interface("wan","dummy")
      --remove the wan interface(copy_interface done next would only merge otherwise)
         scripthelpers.delete_interface("wan") -- yet another commit
      --reload the network topic as it was changed by the scripthelpers functions
         x:load("network")
      --Make Sure that dummy does not come up
         x:set("network", "dummy", "auto", "0" )
         x:commit("network")
   end
   -- no wan interface at this stage.
   if InterfaceMAP[CurrentScenarioName] then
      --Copy the current interface to the WAN
      conn:call("network.interface."..InterfaceMAP[CurrentScenarioName], "down", { })
      scripthelpers.copy_interface(InterfaceMAP[CurrentScenarioName], "wan")
      --Make sure only one comes up:
      x:load("network")
      turnAutoOnOff(x,runtime,l2type,"0")
      --x:set("network", InterfaceMAP[CurrentScenarioName], "auto", "0")
      x:set("network", "wan", "auto", "1")
   else
      runtime.logger:error("L3_"..CurrentScenarioName.."Entry("..l2type.."): no known interface for scenario "..CurrentScenarioName.." in InterfaceMAP.")
      return false
   end
    --Setup correct source interface for auto_iptv
        x:set("network", "auto_iptv", "ifname", "atm_iptv")
    --Enable QoS for ATM device atm_wan
        x:set("qos", "atm_wan", "enable", "1")
        x:commit("qos")
    --Network commit for changes above
        x:commit("network")
        os.execute("/etc/init.d/network reload")
    --XTM & QoS reload mandatory for XTM queues definition
        os.execute("/etc/init.d/qos reload")
        x:commit("xtm")
        os.execute("/etc/init.d/xtm reload")
   return true
end

function M.exit(runtime, l2type)
   local scripthelpers = runtime.scripth
   local conn = runtime.ubus
   local uci = runtime.uci
   local x = uci.cursor()
   -- Reset what we changed in Entry:
   if not InterfaceMAP[CurrentScenarioName] then
      runtime.logger:error("L3_"..CurrentScenarioName.."Exit("..l2type.."): no known interface for scenario "..CurrentScenarioName.." in InterfaceMAP.")
      return false
   end
   scripthelpers.delete_interface("wan")
   if existInterface(x,runtime,"dummy") then
      runtime.logger:warning("L3_"..CurrentScenarioName.."Exit("..l2type.."): found dummy interface. Copied the dummy intf to wan intf.")
      conn:call("network.interface.dummy", "down", { })
      scripthelpers.copy_interface("dummy", "wan")
      scripthelpers.delete_interface("dummy")
      --reload the network topic as it was changed by the scripthelpers functions:
      x:load("network")
      x:delete("network", "interface", "dummy")
      x:set("network", "wan", "auto", "1")
   end
    --Reset services.
    --Disable QoS for ATM device atm_0_35
        x:set("qos", "atm_wan", "enable", "0")
        x:commit("qos")
    --Reset source interface for auto_iptv
        x:set("network", "auto_iptv", "ifname", "SET_BY_SCRIPT")
    --Network commit for changes above
        x:commit("network")
        os.execute("/etc/init.d/network reload")
    --XTM & QoS reload mandatory for XTM queues
        os.execute("/etc/init.d/qos reload")
        x:commit("xtm")
        os.execute("/etc/init.d/xtm reload")
   return true
end

return M
