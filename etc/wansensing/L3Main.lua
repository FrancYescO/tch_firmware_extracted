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
   local conn = runtime.ubus

   if  event == "timeout" then
      -- TODO check the current state of the layer2 interfaces

      local nwifwan = conn:call("network.interface.wan", "status", { })
			
			if nwifwan.up then
			
				local iptest = string.match(nwifwan["ipv4-address"][1]["address"], "%d%d%.")

				local f = io.open("/proc/uptime")
				local line = f:read("*line")
				f:close()

				local up_t = math.floor(string.match(line, "[%d]+"))

				if iptest == "10." and up_t > 86400 then
					conn:call("network.interface.wan","down", {})
				end
				
			end
      return "L3Sense"
   else
      if scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
         return "L2Sense"
      end
   end

   return "L3Sense"
end

return M