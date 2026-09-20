---
-- Module Worker.
-- Module Specifies actions triggered by events
-- @module modulename
local M = {}
local xdslctl = require('transformer.shared.xdslctl')
-- Advanced Event Registration (availabe for version >= 1.0)
--
--   List of events can be changed during runtime
--   By default NOT registered for 'timeout' event
--   Support implemented for :
--       a) network interface updates coded as `network_interface_xxx_yyy` (xxx= OpenWRT interface name, yyy = ifup/ifdown)
--           network_interface_xxx_up:
--                   event is used to flag the logical OpenWRT interface changed state from down to up
--                   event is used to flag address/route/data updates on this OpenWRT interface
--           network interface_xxx_down:
--                   event is used to flag the logical OpenWRT interface changed state from up to down
--       b) dslevents
--                   xdsl_0(=AdslTrainingIdle, idle)
--                   xdsl_1(=AdslTrainingG994)
--                   xdsl_2(=AdslTrainingG992Started)
--                   xdsl_3(=AdslTrainingG992ChanAnalysis)
--                   xdsl_4(=AdslTrainingG992Exchange)
--                   xdsl_5(=AdslTrainingConnected, showtime)
--                   xdsl_6(=AdslTrainingG993Started)
--                   xdsl_7(=AdslTrainingG993ChanAnalysis)
--                   xdsl_8(=AdslTrainingG993Exchange)
--       c) network device state changes coded as 'network_device_xxx_yyy' (xxx = linux netdev, yyy = up/down)
--       d) add/delete events raised by the neighbour daemon
--            scripthelper function available to create the event strings,see 'scripthelpers.formatNetworkNeighborEventName(l2intf,add,neighbour)'
--       e) start event which is raised to indicate the worker needs to start.
--
-- @SenseEventSet [parent=#M] #table SenseEventSet
M.SenseEventSet = {
    ['start'] = true,
    ['network_interface_wan_ifup'] = true,
    ['network_interface_wan_ifdown'] = true,
    ['check_network_wan'] = true,
}
local timer

--Change State Function to either bring up/down the wwan
local function Change_WWAN(runtime, target_state)
    local conn = runtime.ubus
    local uci = runtime.uci
    local x = uci.cursor()
    local status = {
        ["up"] = 1,
        ["down"] = 0
    }
    local curr_status = x:get("network", "wwan", "auto")
    if curr_status ~= tostring(status[target_state]) then
       x:set("network", "wwan", "auto", status[target_state])
       x:commit("network")
       conn:call("network.interface.wwan", target_state, { })
    end
end

---
-- Main function called to indicate an event happened.
--
-- @function [parent=M]
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 specifies the event which triggered this check method call (eg. start, network_interface_voip_ifup, network_interface_voip_ifdown)
function M.check(runtime, event)
   local scripthelpers = runtime.scripth
   local conn = runtime.ubus
   local logger = runtime.logger
   if event == "start" then
      if scripthelpers.checkIfInterfaceIsUp("wan") then
         M.check(runtime, "network_interface_wan_ifup")
      else
         M.check(runtime, "network_interface_wan_ifdown")
      end
      return
   elseif event == "network_interface_wan_ifup" then
      timer = scripthelpers.fire_timed_event("check_network_wan", 30, 1)
      return
   elseif event == "check_network_wan" then
      local uptime
      local wanstatus = conn:call("network.interface.wan", "status", {})
      uptime = wanstatus and wanstatus["uptime"] or 0
      if tonumber(uptime) >= 30 then
         logger:warning("WAN Up for more then 30 seconds - Disabling WWAN(Mobile)")
         Change_WWAN(runtime, "down")
      else
         logger:warning("WAN is not Up for more then 30 seconds - Not Disabling WWAN(Mobile)")
      end
      return
   elseif event == "network_interface_wan_ifdown" then
      logger:warning("WAN Down - Enabling WWAN(Mobile)")
      Change_WWAN(runtime, "up")
      return
   end
   return
end

return M
