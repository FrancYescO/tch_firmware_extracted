local M = {}

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down'
}

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
function M.check(runtime, l2type, event)
    local scripthelpers = runtime.scripth

   if  event == "timeout" then
      -- TODO check the current state of the layer2 interfaces
      return "L3Sense"
   else
      if scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
         return "L2Sense"
      end
   end

   return "L3Sense"
end

return M


