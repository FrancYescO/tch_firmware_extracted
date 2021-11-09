local M = {}

M.SenseEventSet = {
    ["start"] = true,
    ["network_interface_lan_ifup"] = true,
    ["timeout"] = true,
}
M.timeout_counter = 0

local function monitorNeighEvent(runtime, intf, nbdelevent)
   if runtime.neighevents[intf] ~= nbdelevent then
      if runtime.neighevents[intf] then
         runtime.logger:notice("unregister from event " .. runtime.neighevents[intf])
         M.SenseEventSet[runtime.neighevents[intf]] = nil
      end
      runtime.logger:notice("register to event " .. nbdelevent)
      runtime.neighevents[intf] = nbdelevent
      M.SenseEventSet[nbdelevent] = true;
   end
end

local function monitorOppositeAddNeighEvent(runtime, intf)
   if runtime.neighevents[intf] then
      local add_event, count = string.gsub(runtime.neighevents[intf], "_delete_", "_add_")
      if count == 1 then
         monitorNeighEvent(runtime, intf, add_event)
      end
   end
end

local function dropNeighEvent(runtime, intf)
   if runtime.neighevents[intf] then
      runtime.logger:notice("unregister from event " .. runtime.neighevents[intf])
      M.SenseEventSet[runtime.neighevents[intf]] = nil
      runtime.neighevents[intf] = nil
   end
end

local function getInterfaceDeviceAndNextHop(conn, intf)
   local ifstatus = conn:call("network.interface." .. intf, "status", { })
   if type(ifstatus) == "table" and ifstatus.up and
      type(ifstatus.device) == "string" and
      type(ifstatus.route) == "table" then

      for _, route in pairs(ifstatus.route) do
         if type(route) == "table" and type(route.nexthop) == "string" and
            route.mask == 0 and route.target == "0.0.0.0" then
            return ifstatus.device, route.nexthop
         end
      end
   end

   return nil
end

function M.check(runtime, event)
   local conn = runtime.ubus
   local scripthelpers = runtime.scripth
   local interface = "lan"

   if runtime.neighevents == nil then
      -- Script initialization
      runtime.neighevents = { }

      local device, nexthop = getInterfaceDeviceAndNextHop(conn, interface)
      if device and nexthop then
         local nbdelevent = scripthelpers.formatNetworkNeighborEventName(device, false, nexthop)
         monitorNeighEvent(runtime, interface, nbdelevent)
         M.SenseEventSet["timeout"] = nil -- timeout event is no longer needed
      end
   end

   if event == "network_interface_lan_ifup" then
      local device, nexthop = getInterfaceDeviceAndNextHop(conn, interface)
      if device and nexthop then
         local nbdelevent = scripthelpers.formatNetworkNeighborEventName(device, false, nexthop)
         monitorNeighEvent(runtime, interface, nbdelevent)
         M.SenseEventSet["timeout"] = nil -- timeout event is no longer needed
      end
   elseif event and event == runtime.neighevents[interface] then
      -- If this is a delete neigh event, enable correspondent add neigh event
      -- so we could speed up DHCP lease retrieval when next hop is reachable again
      monitorOppositeAddNeighEvent(runtime, interface)

      -- next hop became (un)reachable, renew DHCP lease
      runtime.logger:notice("trigger " .. interface .. " DHCP lease renewal")
      conn:call("network.interface." .. interface, "renew", {})
      if M.SenseEventSet["timeout"] == nil then
         M.SenseEventSet["timeout"] = true
         M.timeout_counter = 0
         runtime.async.timerstart(15000) -- rearm timer (might had been stopped)
      end
    elseif event == "timeout" and M.SenseEventSet["timeout"] then
      M.timeout_counter = M.timeout_counter + 1
      if M.timeout_counter > 2 then
         -- Release DHCP lease
         runtime.logger:notice("trigger " .. interface .. " DHCP lease release")
         os.execute("killall -USR2 odhcpc")
         M.SenseEventSet["timeout"] = nil -- timeout event is no longer needed
      end

      -- DHCP renewal timeout, trigger DHCP lease renewal again
      runtime.logger:notice("trigger " .. interface .. " DHCP lease renewal")
      conn:call("network.interface." .. interface, "renew", {})
    end
    return
end

return M
