package.path = "/etc/wansensing/lib/?.lua;" .. package.path
local myhelpers = require("Scenario")

local M = {}
--[[************* COPYRIGHT AND CONFIDENTIALITY INFORMATION ***************
--** Copyright © 2014 - 2018 TECHNICOLOR DELIVERY TECHNOLOGIES, SAS       **
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

M.SenseEventSet = {
    ['timeout'] = true,
    ['xdsl_0'] = true,
    ['xdsl_5'] = true,
    ['network_device_eth4_down'] = true,
    ['network_device_eth4_up'] = true,
    ['network_interface_wan_ifup'] = true,
    ['network_interface_dummy_ifup'] = true,
    ['network_interface_adsl_ifup'] = true,
    ['network_interface_vdsl_ifup'] = true,
    ['network_interface_ewan_ifup'] = true,
}

-- Functions

-- Local variables
local ADSL_DataScenarios = myhelpers.ADSL_DataScenarios
local VDSL_DataScenarios = myhelpers.VDSL_DataScenarios
local ETH_DataScenarios = myhelpers.ETH_DataScenarios
-- This will allow to map between interface name and scenario name
local ScenarioMAP = myhelpers.ScenarioMAP
--local InterfaceMAP = myhelpers.InterfaceMAP


--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
function M.check(runtime, l2type, event)
   local scripthelpers = runtime.scripth
   local conn = runtime.ubus
   local uci = runtime.uci
   local logger = runtime.logger
   local cur = uci:cursor()
   local CurrentDataScenarios = {}
   -- IP interfaces coming up
   local UPevents = {}

   --limit the scope to the relevant physical layer as sensed in L2.
   if l2type == "ADSL" then
      CurrentDataScenarios = ADSL_DataScenarios
   elseif l2type == "VDSL" then
      CurrentDataScenarios = VDSL_DataScenarios
   elseif l2type == "ETH" then
      CurrentDataScenarios = ETH_DataScenarios
   end
   --Maximum of one scenario per physical layer type so we choose the first one
   local name, test = next(CurrentDataScenarios)

   if  event == "timeout" then
      --Check if we missed any interface coming up
      local nwifwan = conn:call("network.interface.wan", "status", { })
      if nwifwan and nwifwan.up then
         logger:notice("network.interface.wan is up")
         if name then
            if ScenarioMAP[name] then
               return ScenarioMAP[name]
            else
               logger:error("L3Main("..l2type..", "..event.."): no known scenario for "..name.." in ScenarioMAP.")
            end
         else
            logger:error("L3Main("..l2type..", "..event.."): no known scenario.")
         end
      end
      local wwan_auto = cur:get("network", "wwan", "auto")
      if l2type == "MOBILE" then
         if wwan_auto == "0" then
            return "L2Sense"
         end
      end
      local mobiled_enabled = cur:get("mobiled", "globals", "enabled")
      if mobiled_enabled == nil then   -- in case of this option is missed
         mobiled_enabled = "1"   -- default value is 1
      end
      local autofailover = cur:get("wansensing", "global", "autofailover")
      if (autofailover == "1") and (wwan_auto == "0") then  -- If automatic failover and wwan auto isn't yet enabled
         if mobiled_enabled == "1" then -- and if mobiled is enabled
            local ltebackup_delay_counter_value = (l2type == "ETH" and 1) or 11 -- If connection is Ethernet WAN then wait 2 polls, otherwise wait for 12 polls
            runtime.ltebackup_delay_counter = runtime.ltebackup_delay_counter or 0
            if runtime.ltebackup_delay_counter > ltebackup_delay_counter_value then -- Once number of polls reached
               local device = conn:call("mobiled", "status", {}) -- Check that status of mobiled
               if device and device.status ~= "WaitingForDevice" then -- If it has started up correctly then enable the wwan interface
                  if wwan_auto == "0" then
                     logger:notice("WAN Sensing - Enabling Mobile interface")
                     cur:set("network", "wwan", "auto", "1")
                     cur:commit("network")
                     os.execute("/etc/init.d/network reload")
                  end
                  return "L3Sense", "MOBILE"
               end
            else
	           runtime.ltebackup_delay_counter = runtime.ltebackup_delay_counter + 1
            end
         end
      end
   elseif event == "network_interface_wan_ifup" then
      --format: network_interface_wan_ifup
      local current_intf = event:match("s*network_interface_(.-)_ifup%s*$")
      if current_intf==nil then
        logger:notice("Event "..event..": Unable to verify the current interface.")
        return "L3Sense"
      end

      if name then
         logger:notice("L3Main("..l2type..", "..event.."): Sensing: "..name.." came up.")
         -- Move to the appropriate L3 mode.
         if ScenarioMAP[name] then
            return ScenarioMAP[name]
         else
            logger:error("L3Main("..l2type..", "..event.."): no known scenario for "..name.." in ScenarioMAP.")
            return "L3Sense"
         end
      else
         logger:error("L3Main("..l2type..", "..event.."): no known scenario.")
         return "L3Sense"
      end
   else
      if l2type == "MOBILE" and (event == "xdsl_5"  or event == "network_device_eth4_up") then
         return "L2Sense"   -- to re-sense and enable primary Intf
      end
   end
   if l2type == 'ETH' then
      if not scripthelpers.l2HasCarrier("eth4") then
         logger:error("L3Main("..l2type..", "..event.."): physical layer went down while sensing.")
         return "L2Sense"
      end
   elseif scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
      logger:error("L3Main("..l2type..", "..event.."): physical layer went down while sensing.")
      return "L2Sense"
   end
   local vodafone_variant = cur:get("env", "var", "vodafone_variant")
   if vodafone_variant == "VHA" then
      -- Curl check for VHA to check if mobile is barred. If a web page can be loaded the http has not been blocked, therefore service is active
      -- If service is active, then mobile LED needs to show connected, and cwmp and VoIP interface switches to mobile
      if scripthelpers.checkIfInterfaceIsUp("wwan") then
         logger:notice("L3Main.lua: check curl delay " .. tostring(runtime.ltebackup_curl_delay_counter) .. " out of " .. tostring(runtime.ltebackup_curl_delay_counter_value))
         if runtime.ltebackup_curl_delay_counter == 0 then
            local curlurl = cur:get("env","var","curlurl") or "barred-check.vodafone.net.au"
            if myhelpers.send_curl_status(curlurl,myhelpers.wwan_intf) == 1 then
               conn:send("mobile", { event = "internet_connected"})
	           local currentstate = cur:get("cwmpd", "cwmpd_config", "interface")
               if currentstate ~= "wwan_4" then
                  cur:set("cwmpd", "cwmpd_config", "interface", "wwan_4")
                  cur:set("cwmpd", "cwmpd_config", "interface6", "wwan_6")
                  cur:commit("cwmpd")
                  os.execute("/etc/init.d/cwmpd reload")
               end
               -- No need to worry about mmpbxrvsipnet.sip_net.interface as VHA does not have voice
               if (cur:get("web","remote", "interface") ~= "wan") then
                  cur:set("web", "remote", "interface", "wan")
                  cur:commit("web")
                  run_command(runtime, "wget http://127.0.0.1:55555/ra?remote=reload_interface -O-")
               end
               runtime.ltebackup_curl_delay_counter_value = 11  -- 60s = 5s poll x (11 + 1)
            else
               conn:send("mobile", { event = "barred"})
               runtime.ltebackup_curl_delay_counter_value = 5  -- 30s = 5s poll x (5 + 1)
            end
            runtime.ltebackup_curl_delay_counter = 1
         elseif runtime.ltebackup_curl_delay_counter >= runtime.ltebackup_curl_delay_counter_value then
            runtime.ltebackup_curl_delay_counter = 0
         else
            runtime.ltebackup_curl_delay_counter = runtime.ltebackup_curl_delay_counter + 1
         end
	  else
         conn:send("mobile", { event = "limited_service"})
      end
   end
   return "L3Sense"
end

return M
