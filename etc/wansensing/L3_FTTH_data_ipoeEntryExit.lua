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

local CurrentScenarioName="FTTH_data_ipoe" -- should match with ./lib/scenario.lua

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
   --[[ As discussed with JP, we copy the interface to wan and turn it off using the auto parameter]]
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
      x:load("network")
      --Make sure only one comes up:
      turnAutoOnOff(x,runtime,l2type,"0")
      --x:set("network", InterfaceMAP[CurrentScenarioName], "auto", "0")
      x:set("network", "wan", "auto", "1")
   else
      runtime.logger:error("L3_"..CurrentScenarioName.."Entry("..l2type.."): no known interface for scenario "..CurrentScenarioName.." in InterfaceMAP.")
      return false
   end
    --Network commit for changes above
    --Setup correct upstream interface for IGMP Proxy
        x:set("igmpproxy", "auto_iptv", "state", "inactive")
        x:set("igmpproxy", "FTTH_TIVO", "state", "upstream")
        x:commit("igmpproxy")
        os.execute("/etc/init.d/igmpproxy restart")
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
    --Reset upstream interface for IGMP Proxy
           x:set("igmpproxy", "auto_iptv", "state", "upstream")
           x:set("igmpproxy", "FTTH_TIVO", "state", "inactive")
           x:commit("igmpproxy")
           os.execute("/etc/init.d/igmpproxy restart")
    --Network commit for changes above
        x:commit("network")
        os.execute("/etc/init.d/network reload")
   return true
end

return M
