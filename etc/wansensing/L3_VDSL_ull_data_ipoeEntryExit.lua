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

local CurrentScenarioName="VDSL_ull_data_ipoe" -- should match with ./lib/scenario.lua

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
    --Setup static route for ull_voice interface
        x:set("network" , "voip_staticroute", "interface" , "vdsl_ull_voice")
        x:set("network" , "voip_staticroute2", "interface" , "vdsl_ull_voice")
    --Setup correct source interface for auto_iptv
        x:set("network", "auto_iptv", "ifname", "ptm0_vlan105")
    --Setup MMPBX on vdsl_ull_voice interface (static IPoE)
        x:set("mmpbxrvsipnet", "sip_net", "interface", "vdsl_ull_voice")
        x:commit("mmpbxrvsipnet")
    --Network commit for changes above
        x:commit("network")
        os.execute("/etc/init.d/network reload")
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
      x:set("network", "wan", "auto", "1")
   end
    --Reset services
    --Reset static route for VoIP
        x:set("network" , "voip_staticroute", "interface" , "SET_BY_SCRIPT")
        x:set("network" , "voip_staticroute2", "interface" , "SET_BY_SCRIPT")
    --Reset source interface for auto_iptv
        x:set("network", "auto_iptv", "ifname", "SET_BY_SCRIPT")
    --Reset MMPBX on wan interface
        x:set("mmpbxrvsipnet", "sip_net", "interface", "wan")
        x:commit("mmpbxrvsipnet")
        os.execute("/etc/init.d/mmpbxd reload")
    --Network commit for changes above
        x:commit("network")
        os.execute("/etc/init.d/network reload")
   return true
end

return M
