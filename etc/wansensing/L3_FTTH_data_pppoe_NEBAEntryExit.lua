package.path = "/etc/wansensing/lib/?.lua;" .. package.path
local myhelpers = require("Scenario")

local M = {}
--[[************* COPYRIGHT AND CONFIDENTIALITY INFORMATION ***************
--** Copyright © 2014 - 2017 TECHNICOLOR DELIVERY TECHNOLOGIES, SAS       **
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

local CurrentScenarioName="FTTH_data_pppoe_NEBA" -- should match with ./lib/scenario.lua

local function existInterface(x,runtime,name)
   return myhelpers.existInterfaceCommon(x,runtime,name,CurrentScenarioName)
end

-- when given a cursor, change the target of a qos reclassify rule of auto_iptv
-- Function introduced for VULA scenario support
local function change_qos_reclassify_target(runtime, x, from, to)
   local logger = runtime.logger
   local change_sections = {}
   x:foreach('qos', 'reclassify', function(s)
      if s['target'] == from then
         local contains_auto_iptv = false
         if type(s['dstif']) == 'table' then
            for _, elm in ipairs(s['dstif']) do
               if elm == "auto_iptv" then
                  contains_auto_iptv = true
               end
            end
         elseif type(s['dstif']) == 'string' and s['dstif'] == "auto_iptv" then
            contains_auto_iptv = true
         end
         if contains_auto_iptv then
            change_sections[#change_sections + 1] = s['.name']
         end
      end
   end)
   for _, section in ipairs(change_sections) do
      x:set('qos', section, 'target', to)
   end
   if #change_sections > 0 then
      logger:notice("qos_reclassify_target changed "..from.." -> "..to .. " for auto_iptv interface")
   end
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
      --Setup Network changes for VULA
        x:set("network","auto_iptv", "ifname", "vlan24")
        x:set("network","auto_iptv", "hostname", "vfh-500t")
        x:set("network","vlan24", "igmpversion", "2")
      --Change WAN firewall zone
        x:set("firewall", "wan", "network", {
         "wan",
         "wan6",
         "wwan",
         "adsl_wholesales_NEBA",
         "adsl_wholesales",
         "ull_data",
         "vdsl_ull_data_ipoe",
         "vdsl_ull_data_pppoe",
         "FTTH_data_pppoe",
         "FTTH_data_ipoe"
   })
   x:commit('firewall')
   os.execute("/etc/init.d/firewall restart")
     -- Set QoS for auto_iptv interface
   change_qos_reclassify_target(runtime, x, 'IPTV', 'VULA')
   x:commit("qos")
   os.execute("/etc/init.d/qos reload")
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
    --Reset QoS for IPTV label
        x:set("qos", "IPTV", "pcp", "4")
    --Reset Network changes
        x:set("network","auto_iptv", "ifname", "SET_BY_SCRIPT")
        x:delete("network","auto_iptv", "hostname")
        x:delete("network", "vlan24", "igmpversion")
    --Reset WAN firewall zone
        x:set("firewall", "wan", "network", {
          "wan",
          "wan6",
          "wwan",
          "adsl_wholesales_NEBA",
          "adsl_wholesales",
          "ull_data",
          "vdsl_ull_data_ipoe",
          "vdsl_ull_data_pppoe",
          "FTTH_data_pppoe",
          "FTTH_data_ipoe",
          "FTTH_data_pppoe_NEBA"
   })
   x:commit('firewall')
   os.execute("/etc/init.d/firewall restart")
     -- Reset QoS for auto_iptv interface
   change_qos_reclassify_target(runtime, x, 'VULA', 'IPTV')
   x:commit("qos")
   os.execute("/etc/init.d/qos reload")
   x:commit("network")
   os.execute("/etc/init.d/network reload")
   return true
end

return M
