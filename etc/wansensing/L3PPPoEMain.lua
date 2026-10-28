local M = {}

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down'
}

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
function M.check(runtime, l2type, event)
   local uci = runtime.uci
   local conn = runtime.ubus
   local logger = runtime.logger
   local scripthelpers = runtime.scripth
   
--   logger:notice("The L3PPPoE main script is checking link connectivity and DHCP on l2type interface " .. tostring(l2type))
   
   if event == "timeout" then
      -- TODO check the current state of the layer2 interfaces
      return "L3PPPoE"
   else
      if scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
         return "L2Sense"
      end
--      return "L3PPPoE" -- if we get there, then we're not concerned, the non used L2 went down
   end
end

return M


