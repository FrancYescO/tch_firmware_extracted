package.path = "/etc/wansensing/lib/?.lua;" .. package.path
local myhelpers = require("Scenario")
local InterfaceMAP = myhelpers.InterfaceMAP
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

local CurrentScenarioName="ADSL" -- should match with ./lib/scenario.lua and config

M.SenseEventSet = {
    ['timeout'] = true,
    ['xdsl_0'] = true,
    ['network_interface_wan_ifdown'] = true,
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

local function PPPUsernameWatch(runtime,intf)
   local uci = runtime.uci
   local cur = uci:cursor()
   local Need2Update = false
   local pppIntf
   local ADSL_DataScenarios = myhelpers.ADSL_DataScenarios
   local VDSL_DataScenarios = myhelpers.VDSL_DataScenarios
   local ETH_DataScenarios = myhelpers.ETH_DataScenarios
   local intfproto = cur:get("network",intf,"proto")
   local adslname, vdslname, ewanname, test, adslproto, vdslproto, ewanproto
   adslname, test = next(ADSL_DataScenarios)
--   vdslname, test = next(VDSL_DataScenarios)
--   ewanname, test = next(ETH_DataScenarios)
   if adslname then
      adslproto = cur:get("network",adslname,"proto")
   end
--   if vdslname then
--      vdslproto = cur:get("network",vdslname,"proto")
--   end
--   if ewanname then
--      ewanproto = cur:get("network",ewanname,"proto")
--   end
   if intfproto and (intfproto == "pppoa" or intfproto == "pppoe") then
      pppIntf = intf
--   else
--      if adslproto and (adslproto == "pppoa" or adslproto == "pppoe") then
--         pppIntf = adslname
--      else
--         if vdslproto and (vdslproto == "pppoa" or vdslproto == "pppoe") then
--            pppIntf = vdslname
--         else
--            if ewanproto and (ewanproto == "pppoa" or ewanproto == "pppoe") then
--               pppIntf = ewanname
--            end
--         end
--      end
--   end
--   if pppIntf then
      local wanusername = cur:get("network","wan","username")
      local wanpassword = cur:get("network","wan","password")
      if wanusername then
         local intfusername = cur:get("network",pppIntf,"username")
         if intfusername and wanusername ~= intfusername then
            if adslproto and (adslproto == "pppoa" or adslproto == "pppoe") then
               cur:set("network",adslname,"username",wanusername) 
               cur:set("network",adslname,"password",wanpassword) 
            end
--            if vdslproto and (vdslproto == "pppoa" or vdslproto == "pppoe") then
--               cur:set("network",vdslname,"username",wanusername) 
--               cur:set("network",vdslname,"password",wanpassword) 
--            end
--            if ewanproto and (ewanproto == "pppoa" or ewanproto == "pppoe") then
--               cur:set("network",ewanname,"username",wanusername) 
--               cur:set("network",ewanname,"password",wanpassword) 
--            end
            cur:commit("network")
         end
      end
   end
end

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
function M.check(runtime, l2type, event)
   local scripthelpers = runtime.scripth
   local conn = runtime.ubus
   local uci = runtime.uci
   local cur = uci:cursor()
   -- Events that indicate a migration occured:
   local UPevents = myhelpers.UPevents
   local FAILevents = {--['cc_iptv_fail'] = true,
                       --['cc_voip_fail'] = true,
}

   if  event == "timeout" then
      --Check if we missed any interface coming up
      --TBD

      --Check all is well:
      local nwifwan = conn:call("network.interface.wan", "status", { })

      if nwifwan and nwifwan.up then
         retry = 0
         PPPUsernameWatch(runtime,InterfaceMAP[CurrentScenarioName])
         local RxCheck = myhelpers.RxByteCheck(runtime)
         if RxCheck ~= 0 then
            os.execute("cat /proc/net/dev_extstats; xtmctl operate intf --stats; xdslctl info --stats; xdslctl info")
         end
         if RxCheck > 0 then
            runtime.logger:error("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): Rx Bytes not incrementing.")
            return CurrentScenarioName, true
         elseif RxCheck == -1 then
            if not myhelpers.checkPing(scripthelpers, runtime.logger, "atm_wan") then
               local intfproto = cur:get("network","wan","proto")
               if intfproto and (intfproto == "pppoa" or intfproto == "pppoe") then
               else
                  runtime.logger:error("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): ping failed. go back to L3Sense.")
                  return "L3Sense", l2type
               end
            end
         end
      else
         if not myhelpers.currentL2Up(runtime, l2type, "eth4") then
            return "L2Sense"
         end
         if retry > 10 then
            -- I randomly set to 10 after 2*5seconds was not enough on my setup.
            runtime.logger:error("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): wan is down. retry reached "..retry.." go back to L2Sense.")
            retry = 0
            return "L3Sense", l2type
         else
            runtime.logger:notice("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): wan is down. retry incremented by 1 ("..retry..").")
            conn:call("network.interface.wan", "up", { })
            retry = retry + 1
         end
      end
      return CurrentScenarioName

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
      os.execute("cat /proc/net/dev_extstats; xtmctl operate intf --stats; xdslctl info --stats; xdslctl info")
      if scripthelpers.checkIfInterfaceIsUp("wan") == false then
        runtime.logger:notice("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): wan interface went down.")
        --return "L3Sense"
        retry = retry + 1
        return CurrentScenarioName
      else
        runtime.logger:notice("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): wan interface went down and up.")
        return CurrentScenarioName
      end
   elseif scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
      runtime.logger:error("L3_"..CurrentScenarioName.."Main("..l2type..", "..event.."): Error: physical layer went down.")
      return "L2Sense"
   end
--   return CurrentScenarioName
end

return M
