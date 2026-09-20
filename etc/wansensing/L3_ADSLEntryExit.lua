package.path = "/etc/wansensing/lib/?.lua;" .. package.path
local myhelpers = require("Scenario")
local proxy = require("datamodel")

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

local CurrentScenarioName="ADSL" -- should match with ./lib/scenario.lua

--Map between interface name and scenario name
local ScenarioMAP = myhelpers.ScenarioMAP
local InterfaceMAP = myhelpers.InterfaceMAP

function M.entry(runtime, l2type)
   local uci = runtime.uci
   local conn = runtime.ubus
   local x = uci.cursor()
   runtime.logger:notice("L3_"..CurrentScenarioName.."Entry("..l2type..")")
    local result = proxy.get("rpc.network.interface.@wan.rx_bytes")
    runtime.l3rx_bytes = result and result[1].value or 0
	runtime.l3dhcp_failures = 0
    runtime.logger:notice("The L3DHCP entry script is checking Rx Bytes: " .. tostring(runtime.l3rx_bytes))
   return true
end

function M.exit(runtime, l2type, event)
   local scripthelpers = runtime.scripth
   local uci = runtime.uci
   local conn = runtime.ubus
   local x = uci.cursor()
   runtime.logger:notice("L3_"..CurrentScenarioName.."Exit("..l2type..", "..event..")")
   if event == "L2Sense" then
      --only do something if lower layer goes down
      CurrentScenario = InterfaceMAP[CurrentScenarioName]
	  if CurrentScenario then
	     --Copy the WAN to the current interface and then dummy to wan
         conn:call("network.interface.wan", "down", { })
         scripthelpers.delete_interface(CurrentScenario)
         scripthelpers.copy_interface("wan",CurrentScenario)
         scripthelpers.delete_interface("wan") -- yet another commit
         scripthelpers.copy_interface("dummy","wan")
         x:load("network")
         x:set("network", CurrentScenario, "auto", "0" )
         x:set("network", "wan", "auto", "0" )
         x:commit("network")
         -- release global IPv6 address on br-lan and on lan clients
         conn:call("network.interface.lan", "down", { })
         conn:call("network.interface.lan", "up", { })
         local lanifname = x:get("network", "lan", "ifname")
         if lanifname then
             for interface in string.gmatch(lanifname, "[^%s]+") do
                 os.execute("/usr/bin/ethctl " .. interface .. " phy-power down")
                 os.execute("/usr/bin/ethctl " .. interface .. " phy-power up")
             end
         end
         runtime.logger:notice("L3_"..CurrentScenarioName.."Exit("..l2type.."): Scenario for interface "..CurrentScenario..".")
	  else
         runtime.logger:error("L3_"..CurrentScenarioName.."Exit("..l2type.."): no known Scenario for interface "..CurrentScenario..".")
         return false
	  end
   else
      conn:call("network.interface.wan", "down", { })
      conn:call("network.interface.wan", "up", { })
   end
   return true
end

return M
