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

local CurrentScenarioName = "NONE"

local function existInterface(x,runtime,name)
   return myhelpers.existInterfaceCommon(x,runtime,name,CurrentScenarioName)
end

--Map between interface name and scenario name
local ScenarioMAP = myhelpers.ScenarioMAP
local InterfaceMAP = myhelpers.InterfaceMAP
local Scenarios = myhelpers.Scenarios

local lowerinterfaces2Scenario = {
	atm_wan = "ADSL",
	ptm0 = "VDSL",
	vlanptm0 = "VDSL",
	eth4 = "EWAN",
	vlanwan = "EWAN",
}

local interfaces = {
	ADSL = "adsl",
	VDSL = "vdsl",
	ETH = "ewan"
}

function M.entry(runtime, l2type)
   local scripthelpers = runtime.scripth
   local uci = runtime.uci
   local conn = runtime.ubus
   local logger = runtime.logger
   local x = uci.cursor()

   local CurrentDataScenarios 
   runtime.logger:notice("L3Entry("..l2type..")")
   if l2type == "ADSL" then
      CurrentDataScenarios = myhelpers.ADSL_DataScenarios
   elseif l2type == "VDSL" then
      CurrentDataScenarios = myhelpers.VDSL_DataScenarios
   elseif l2type == "ETH" then
      CurrentDataScenarios = myhelpers.ETH_DataScenarios
   elseif l2type == "MOBILE" then
      CurrentDataScenarios = {}
   else
      runtime.logger:error("L2_"..l2type.."): not known.")
      return false
   end
   -- There is only one scenario per L2_type, so we pick the first from the table
   CurrentScenarioName, _ = next(CurrentDataScenarios)
   
   if CurrentScenarioName then
      --Sanity Check to make sure CurrentScenarioName has valid Data
      local ifname = x:get("network", CurrentScenarioName, "ifname")
      if not ifname or not lowerinterfaces2Scenario[ifname] or lowerinterfaces2Scenario[ifname] ~= Scenarios[CurrentScenarioName]["ifname"] then
         x:set("network", CurrentScenarioName, "ifname", Scenarios[CurrentScenarioName]["ifname"])
         x:commit("network")
      end
      local proto = x:get("network", CurrentScenarioName, "proto")
      if not proto then
         x:set("network", CurrentScenarioName, "proto", Scenarios[CurrentScenarioName]["proto"])
         x:commit("network")
	     proto = Scenarios[CurrentScenarioName]["proto"]
      end
      if proto == "dhcp" then
         local reqopts = x:get("network", CurrentScenarioName, "reqopts")
         if not reqopts then
            x:set("network", CurrentScenarioName, "reqopts", Scenarios[CurrentScenarioName]["reqopts"])
            x:commit("network")
         end
      elseif proto == "pppoa" then
         local vpi = x:get("network", CurrentScenarioName, "vpi")
         if not vpi then
            x:set("network", CurrentScenarioName, "vpi", Scenarios[CurrentScenarioName]["vpi"])
            x:set("network", CurrentScenarioName, "vci", Scenarios[CurrentScenarioName]["vci"])
            x:set("network", CurrentScenarioName, "encaps", Scenarios[CurrentScenarioName]["encaps"])
            x:commit("network")
         end
         local username = x:get("network", CurrentScenarioName, "username")
         if not username then
            x:set("network", CurrentScenarioName, "username", Scenarios[CurrentScenarioName]["username"])
            x:set("network", CurrentScenarioName, "password", Scenarios[CurrentScenarioName]["password"])
            x:commit("network")
         end
      end
      local ipv6 = x:get("network", CurrentScenarioName, "ipv6")
      if not ipv6 then
         x:set("network", CurrentScenarioName, "ipv6", Scenarios[CurrentScenarioName]["ipv6"])
         x:commit("network")
      end
   
      -- Copy the interface settings to the WAN:
      if existInterface(x,runtime,"wan") then
         --remove the wan interface(copy_interface done next would only merge otherwise)
         scripthelpers.delete_interface("wan") -- yet another commit
         --reload the network topic as it was changed by the scripthelpers functions
         x:load("network")
         --Make Sure that dummy does not come up
         x:set("network", "dummy", "auto", "0" )
         x:commit("network")
      end
      -- no wan interface at this stage.
      if l2type == "ADSL" then
         --Enable QoS for ATM device atm_wan
         x:set("qos", "atm_wan", "enable", "1")
         x:commit("qos")
         --XTM & QoS reload mandatory for XTM queues definition
         os.execute("/etc/init.d/qos reload")
         x:commit("xtm")
         os.execute("/etc/init.d/xtm reload")
         os.execute("sleep 2")
      end
      --Copy the current interface to the WAN
      conn:call("network.interface."..CurrentScenarioName, "down", { })
      scripthelpers.copy_interface(CurrentScenarioName, "wan")
      --Make sure only one comes up:
      x:load("network")
      x:delete("network", CurrentScenarioName, "ifname")
      x:set("network", CurrentScenarioName, "auto", "0")
      x:set("network", "wan", "auto", "1")
      --Network commit for changes above
      x:commit("network")
      os.execute("/etc/init.d/network reload")
      conn:call("network.interface.wan", "up", { })
   else
      runtime.logger:notice("L3Entry("..l2type.."): no known interface for interface "..l2type..".")
   end
   -- initialize failures counter
   runtime.l3dhcp_failures = 0
   return true

end

function M.exit(runtime, l2type, event)
   local scripthelpers = runtime.scripth
   local uci = runtime.uci
   local conn = runtime.ubus
   local x = uci.cursor()
   runtime.logger:notice("L3Exit("..l2type..", "..event..")")
   if event == "L2Sense" then
      --only do something if lower layer goes down
      --lower layer of wan determines the current interface
	  local wanifname = x:get("network", "wan", "ifname")
	  if wanifname then
	     CurrentScenarioName = lowerinterfaces2Scenario[wanifname]
		 if CurrentScenarioName then
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
               runtime.logger:notice("L3Exit("..l2type.."): Scenario for interface "..CurrentScenario..".")
			else
               runtime.logger:error("L3Exit("..l2type.."): no known Scenario for interface "..wanifname..".")
               return false
		    end
		 else
            runtime.logger:error("L3Exit("..l2type.."): lower interface "..wanifname.." not known.")
            return false
		 end
	  else
         runtime.logger:error("L3Exit("..l2type.."): wan has no lower interface.")
         return false
	  end   
   end
   runtime.ltebackup_curl_delay_counter_value = 5
   runtime.ltebackup_curl_delay_counter = 0
   return true
end

return M
