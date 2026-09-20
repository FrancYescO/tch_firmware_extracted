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

local CurrentScenarioName="FTTH_data_pppoe_NEBA" -- should match with ./lib/scenario.lua and config

M.SenseEventSet = {
    ['timeout'] = true,
    ['xdsl_0'] = true,
    ['network_interface_wan_ifup'] = true,
    ['network_interface_voip_ifup'] = true,
    ['network_interface_iptv_ifup'] = true,
--    ['network_interface_dummy_ifup'] = true,
    ['network_interface_adsl_wholesales_ifup'] = true,
    ['network_interface_adsl_wholesales_NEBA_ifup'] = true,
    ['network_interface_ull_data_ifup'] = true,
    ['network_interface_vdsl_ull_data_ipoe_ifup'] = true,
    ['network_interface_vdsl_ull_data_pppoe_ifup'] = true,
    ['network_interface_FTTH_data_pppoe_ifup'] = true,
    ['network_interface_FTTH_data_ipoe_ifup'] = true,
    ['network_interface_FTTH_data_pppoe_NEBA_ifup'] = true,
    ['network_interface_wan_ifdown'] = true,
    ['cc_iptv_fail'] = true,
--    ['cc_voip_fail'] = true,
}
local IPoE_monitor={}
local check_intervals = {
   iptv       = { 30*60, 10, 10, 10} , -- test every 30 min, on fail retry 3 times with a 10sec interval
   voip       = { 15*60, 10, 10, 10} ,
   auto_iptv = { 1*30, 10, 10, 10} ,
}
local retry = 0

--  create and start watcher
--  intended to be called on an ifup event
local function start_watcher(runtime,intf)
   local scripthelpers = runtime.scripth
   local monitor_name=intf.."-monitor" -- explicit name instead of nil
   -- create an ipv4_neighbour_monitor when we do not have one yet
   if  IPoE_monitor[intf]==nil then
      local nextHop= scripthelpers.getNextHop(intf)
      if nextHop then
      IPoE_monitor[intf]=scripthelpers.create_ipv4_neighbour_monitor(
                            monitor_name,
                            intf,
                            nextHop,
                            check_intervals[intf],
                            'cc_'..intf..'_fail'
                            )
      end
   end
   if IPoE_monitor[intf] then
      -- restarting does no harm (e.g. after 'update')
      IPoE_monitor[intf]:start()
   else
      runtime.logger:warning("L3_"..CurrentScenarioName.."Main: failed to start and create an ipv4_neighbour_monitor for "..intf)
   end
end

-- stops and discard a watcher for an interface
-- intented to be called on an ifdown event
local function stop_watcher(runtime,intf)
 if IPoE_monitor[intf] then
    IPoE_monitor[intf]:stop()
    IPoE_monitor[intf]=nil
 end
end

-- handles events that affect a watcher
-- @param intf  (e.g., iptv, voip)
-- @param event (e.g., ifup ifdown fail timeout)
local function IPoEWatch(runtime, intf, event)
   local conn = runtime.ubus
   local uci = runtime.uci
   local x = uci.cursor()

   runtime.logger:notice("L3_"..CurrentScenarioName.."Main.IPoEWatch handles '"..event.."' for interface "..intf)
   local My_event = event:match("s*network_interface_.+_(.-)%s*$") -- ifup, ifdown or nil
   My_event = My_event and My_event or "timeout"
   if My_event=="timeout" then
      start_watcher(runtime,intf)
   elseif event=="fail" then
      runtime.logger:notice("L3_"..CurrentScenarioName.."Main connectivity check failed on "..intf..", try down and up again")
      --These will generate a cascade of event that can be caught in order to stop the watchers before
      --we leave the mode (I know that generates issues)
      conn:call("network.interface."..intf, "down", { })
      conn:call("network.interface."..intf, "up", { })
   elseif event=="ifup" then
      start_watcher(runtime,intf)
   elseif event=="ifdown" then
      stop_watcher(runtime,intf)
   else
      runtime.logger:error("L3_"..CurrentScenarioName.."Main.IPoEWatch did not handle '"..event.."' for interface "..intf)
   end
end

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
function M.check(runtime, l2type, event)
   local scripthelpers = runtime.scripth
   local conn = runtime.ubus
   local uci = runtime.uci
   -- Events that indicate a migration occured:
   local UPevents = myhelpers.UPevents
   local FAILevents = {['cc_iptv_fail'] = true,
                       --['cc_voip_fail'] = true,
}
   local InterfaceMAP = myhelpers.InterfaceMAP
   local currentStateEvent_prefix = 'network_interface_'..InterfaceMAP[CurrentScenarioName]
   local currentInterfaceNetworkPath = 'network.interface.'..InterfaceMAP[CurrentScenarioName]

   if  event == "timeout" then
      --Check if we missed any interface coming up
      --TBD

      --Check all is well:
      local nwifwan = conn:call("network.interface.wan", "status", { })

      if nwifwan and nwifwan.up then
        retry = 0
        --Start watchers (we want to avoid hick-ups)
        --IPoEWatch(runtime,"voip",event)
        IPoEWatch(runtime,"iptv",event)
      else
         if not myhelpers.currentL2Up(runtime, l2type, "eth4") then
            return "L2Sense"
        end
        if retry > 10 then
          -- I randomly set to 10 after 2*5seconds was not enough on my setup.
          runtime.logger:error("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): wan is down. retry reached "..retry.." go back to L2Sense.")
          retry =0
          return "L2Sense"
        else
          runtime.logger:notice("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): wan is down. retry incremented by 1 ("..retry..").")
          conn:call("network.interface.wan", "up", { })
          retry = retry + 1
        end
      end
      return CurrentScenarioName
   elseif event == currentStateEvent_prefix.."_ifup" then
      -- handle ifup on current scenario:
      local current_intf = InterfaceMAP[CurrentScenarioName]

      local nwifscen = conn:call(currentInterfaceNetworkPath, "status", { })
      if nwifscen and not nwifscen.up then
        --probably a hickup: e.g. ipv6 coming up after we decided to leave l3Main
        -- false positive
        runtime.logger:notice("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): Ignoring up event on current interface ("..current_intf..").")
        return CurrentScenarioName
      else
        --Bad situation 2 wan interfaces up: let's sense again. Assuming it was done from the NOC
        runtime.logger:debug("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): "..current_intf.." came up. Maybe triggered by NOC.")
        runtime.logger:notice("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): "..current_intf.." up, moving to L3Sense.")
        -- stop all monitors
        for k,mon in pairs(IPoE_monitor) do
            mon:stop()
            IPoE_monitor[k]=nil
        end
        return "L3Sense"
      end
   elseif UPevents[event] then
      --network_interface_wan_ifup
      local current_intf = event:match("s*network_interface_(.-)_ifup%s*$")
      if current_intf==nil then
        runtime.logger:notice("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): Event "..event..": Unable to verify the current interface.")
        return CurrentScenarioName
      end
      runtime.logger:debug("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): UPevents: "..current_intf.." came up.")
      runtime.logger:notice("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): UPevents: "..current_intf.." up, moving to L2Sense.")
      -- Move to L2Sense mode. This will trigger up/down.
      -- stop all monitors
      for k,mon in pairs(IPoE_monitor) do
         mon:stop()
         IPoE_monitor[k]=nil
      end
       return "L2Sense"

   elseif FAILevents[event] then
      local current_intf = event:match("s*cc_(.-)_fail%s*$")
      if current_intf==nil then
        runtime.logger:notice("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): Event "..event..": Unable to verify the current interface.")
        return CurrentScenarioName
      end
      IPoEWatch(runtime, current_intf, "fail")
      return CurrentScenarioName
   elseif event=="network_interface_wan_ifdown" then
      --Either an ifdown was done manually or because of PPP/DHCP failure, or
      --The watcher failed and triggered an ifdown.
      --UpdateBackUpState(runtime)
      if scripthelpers.checkIfInterfaceIsUp("wan") == false then
        --return "L3Sense"
        retry = retry + 1
        return CurrentScenarioName
      else
        return CurrentScenarioName
      end
   elseif scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
         runtime.logger:error("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): Error: physical layer went down.")
         return "L2Sense"
   end
--   return CurrentScenarioName
end

return M
