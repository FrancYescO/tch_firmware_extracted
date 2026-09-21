local M = {}

M.SenseEventSet = {
    'xdsl_0',
    'network_interface_voip_ifup'
}

function M.check(runtime, l2type, event)
   local uci=runtime.uci
   local logger = runtime.logger
   local scripthelpers = runtime.scripth
   local x=uci.cursor()
   
   if  event == "timeout"  then
      if runtime.voip_checkinterval_begin == true then
         -- begin of interval
         runtime.voip_checkinterval_begin = false
         return 'L3VoipSense'
      else
         -- end of interval, do a final check
         if scripthelpers.checkIfInterfaceIsUp("voip") then
            return "L3MultiWan" 
         else
            -- no voip interface: we are in IPSE mode!
            -- everything should go over the wan interface
            logger:notice("L3VoipSense: voip interface not up - going to IPSE mode ")
            return "L3SingleWan"
         end
      end
   elseif event == 'network_interface_voip_ifup' then
      -- voip interface up: we are in TELENOR (= 3 interfaces )  mode!
      -- three interfaces must be configured
      logger:notice("L3VoipSense: voip interface up - going to TELENOR mode ")
      return "L3MultiWan"
      
   elseif event == 'xdsl_0' then
      -- we have lost the ADSL connection in the mean time...
      -- return to L2sense
      logger:notice("L3VoipSense: ADSL connection lost, reverting to L2 ")
      
      return "L2Sense"
      
   end
   
   return "L3VoipSense"
end

return M
