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

--   logger:notice("The L3 main script is sensing which dummy interface is up..." .. tostring(l2type))

 --  if event == "timeout" then
      -- start sensing
      -- we know we have L2 sensed ADSL, now we need to see if 
      -- PPPoEoPVC=8.35 or
      -- PPPoAoPVC=8.36 comes alive:
      if scripthelpers.checkIfInterfaceIsUp("wanpppoe") then
--         logger:notice("The L3 main script sensed PPPoE on l2type interface " .. tostring(l2type))
--         logger:notice("L3 main: Moving to L3PPPoE")
         return "L3PPPoE"
	  end
--	     logger:notice("L3Main:dummyPPPoE NOT up. ")
--      end
        
      if scripthelpers.checkIfInterfaceIsUp("wanpppoa") then
--         logger:notice("The L3 main script sensed PPPoA on l2type interface " .. tostring(l2type))
--         logger:notice("L3 main: Moving to L3PPPoA")
         return "L3PPPoA"
	  end
--	     logger:notice("L3Main:dummyPPPoA NOT up. ")
--      end
      
      if l2type == "VDSL" then
--         logger:notice("The L3 main script sensed VDSL " .. tostring(l2type))
--         logger:notice("L3 main: Moving to L3VDSL")
         return "L3VDSL"
      end
       
--new 15mars it35:
      if l2type == "ETH" then
--         logger:notice("The L3 main script sensed ETH " .. tostring(l2type))
--         logger:notice("L3 main: Moving to L3ETH")
         return "L3ETH"
      end	   
	  	
   -- end
   return "L3Sense"
end

return M


