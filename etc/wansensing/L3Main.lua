local M = {}
---
-- List all events with will schedule the check method
--   Support implemented for :
--       a) network interface state changes coded as `network_interface_xxx_yyy` (xxx= OpenWRT interface name, yyy = ifup/ifdown)
--       b) dslevents (xdsl_0(=idle)/xdsl_1/xdsl_2/xdsl_3/xdsl_4/xdsl_5(=show time))
--       c) network device state changes coded as 'network_device_xxx_yyy' (xxx = linux netdev, yyy = up/down)
-- @SenseEventSet [parent=#M] #table SenseEventSet
M.SenseEventSet = {
	["timeout"] = true,
	["network_device_eth4_up"] = true,
	["xdsl_0"] = true,
	["xdsl_5"] = true,
}

local xdslctl = require('transformer.shared.xdslctl')
local match = string.match

--- Given the type of L2 and the name of the ETH wan interface, returns whether the current L2
-- is up or down
--runtime = runtime environment holding references to ubus, uci, logger
-- @param l2type
-- @param ethintf the netdev interface used as wan
-- @return {boolean} true if the current L2 is up
--                   false if the current L2 is down
local function currentL2Up(runtime, l2type, ethintf)
   
   if l2type == "ADSL" or l2type == "VDSL" or l2type == "GFAST" then
      local trans_mode = xdslctl.infoValue("tpstc")
      if trans_mode then
         if match(trans_mode, "ATM") then
            return l2type == "ADSL"
         elseif match(trans_mode, "PTM") then
            local mode = xdslctl.infoValue("mode")
            if match(mode, "VDSL") then
               return l2type == "VDSL"
            elseif match(mode, "G.fast") then
               return l2type == "GFAST"
            end
         end
      end 
   elseif l2type == "ETH" then           -- Fiber support to be added
      return runtime.scripth.l2HasCarrier("eth4")
   end
end


---
-- Main function called if a wansensing L3 state is checked.
--
-- @function [parent=M] 
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @param #3 specifies the event which triggered this check method call (eg. timeout, network_device_atm_8_35_up)
-- @return #1 string specifying the next wansensing state
function M.check(runtime, l2type, event)
   local scripthelpers = runtime.scripth
   local trans_mode = xdslctl.infoValue("tpstc")
   if event == "timeout" then
      if not currentL2Up(runtime, l2type, "eth4") then
            return "L2Sense"
      end
   elseif event == "xdsl_5" then
      -- DSL Up
      --Check if in DSL Mode, if not return to L2 Sensing (Should not hit this as teh DSL Down should have already moved to L2Sensing) 
      if l2type ~= "ADSL" or l2type ~= "VDSL" or l2type ~= "GFAST" then
         return "L2Sense"
      end
   elseif event == "xdsl_0" then
      -- DSL Down
      if scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
         return "L2Sense"
      end
   elseif event == "network_device_eth4_up" then
      -- ETH Up
      -- Only Swithc to ETH mode if the DSL is not in sync
      if trans_mode then
        if l2type ~= "ETH" and not match(trans_mode, "ATM") and not match(trans_mode, "PTM") then
           return "L2Sense"
        end
      end
   end

   return "L3Sense"
end

return M


