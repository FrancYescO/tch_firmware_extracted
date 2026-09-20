-- Module L2 Main.
local M = {}

---
-- List all events with will schedule the check method
--   Support implemented for :
--       a) network interface state changes coded as `network_interface_xxx_yyy` (xxx= OpenWRT interface name, yyy = ifup/ifdown)
--       b) dslevents (xdsl_0(=idle)/xdsl_1/xdsl_2/xdsl_3/xdsl_4/xdsl_5(=show time))
--       c) network device state changes coded as 'network_device_xxx_yyy' (xxx = linux netdev, yyy = up/down)
-- @SenseEventSet [parent=#M] #table SenseEventSet
M.SenseEventSet = {  "xdsl_5" }
 

local xdslctl = require('transformer.shared.xdslctl')

local match = string.match

-- @function [parent=M]
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 specifies the event which triggered this check method call (eg. timeout, network_device_atm_8_35_up)
-- @return #1 string specifying the next wansensing state
-- @return #2 string specifying the sensed layer 2 type, this string is passed as input parameter in the L2 Exit function and L3 function API
function M.check(runtime)
    local scripthelpers = runtime.scripth
    local uci = runtime.uci
    local logger = runtime.logger
    local conn = runtime.ubus

    if not uci then
       return false
    end
    local x = uci.cursor()

    -- check if xDSL is up
    local trans_mode = xdslctl.infoValue("tpstc")
    if trans_mode then
      if match(trans_mode, "ATM") then
         logger:notice("Changing to ADSL Mode")
         return "L3Sense", "ADSL"
      elseif match(trans_mode, "PTM") then
         local mode = xdslctl.infoValue("mode")
         if match(mode, "VDSL") then
            logger:notice("Changing to VDSL Mode")
            return "VDSLSense", "VDSL"
         elseif match(mode, "G.fast") then
            logger:notice("Changing to G.Fast Mode")
            return "L3Sense", "GFAST"
         end
      end
    end
    -- check if wan ethernet port is up
    -- TODO SFP sense
    if scripthelpers.l2HasCarrier("eth4") then
     logger:notice("Changing to ETH Mode")
     return "L3Sense", "ETH"
    end
 
     return "L2Sense"     
end

return M
