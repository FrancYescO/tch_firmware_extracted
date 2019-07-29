--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
--NG-105062 Wansensing, modify to new requirements with COC Version1
local M = {}
---
-- List all events with will schedule the check method
--   Support implemented for :
--       a) network interface state changes coded as `network_interface_xxx_yyy` (xxx= OpenWRT interface name, yyy = ifup/ifdown)
--       b) dslevents (xdsl_1(=idle)/xdsl_2/xdsl_3/xdsl_4/xdsl_5(=show time))
--       c) network device state changes coded as 'network_device_xxx_yyy' (xxx = linux netdev, yyy = up/down)
-- @SenseEventSet [parent=#M] #table SenseEventSet
M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wan_ifup',
    'network_interface_wan_ifdown',
}

local xdslctl = require('transformer.shared.xdslctl')

local match = string.match
---
-- Main function called if a wansensing L3 state is checked.
--
-- @function [parent=M]
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @param #3 specifies the event which triggered this check method call (eg. timeout, network_device_atm_8_35_up)
-- @return #1 string specifying the next wansensing state

-- DR - Check L2 states and return to the L2 Sense if needed
--	Check L3 States and return to the L3 Sense if needed

function M.check(runtime, l2type, event)
  local scripthelpers = runtime.scripth
  local optical = require('transformer.shared.optical')
  local conn = runtime.ubus
  local logger = runtime.logger
  local uci = runtime.uci
  local x = uci.cursor()
  local current = x:get("wansensing", "global", "l2type")
  logger:notice("WAN Sensing L3 Up Checking")
  local s_variant = x:get("env", "var", "hardware_version") == "VBNT-S" and true or false
  if not uci then
      return false
  end
  if scripthelpers.checkIfInterfaceIsUp("wan") then
    return "L3UpSense"
  end
  local mode = xdslctl.infoValue("tpstc")
  if (not match(mode, "ATM")) and (not match(mode, "PTM")) and (not scripthelpers.l2HasCarrier("eth4")) then
    logger:notice("Changing to L2 Sense")
    return "L2Sense"
  end
  -- to handle priority WAN connection type for VBNT-S
  if s_variant then
    if mode then
      if match(mode, "ATM") and current ~= "ADSL" then
        logger:notice("Changing to ADSL From " .. current)
        return "L2Sense"
      elseif match(mode, "PTM") and current ~= "VDSL" then
        logger:notice("Changing to VDSL From " .. current)
        return "L2Sense"
      end
    end
    logger:notice("Current Mode " .. current)
    -- check if wan ethernet port is up
    if (not match(mode, "ATM")) and (not match(mode, "PTM")) then
      if (scripthelpers.l2HasCarrier("eth4") and optical.getWanType() == "SFP") and current ~= "SFP" then
        logger:notice("Changing to SFP From " .. current)
        return "L2Sense"
      elseif (scripthelpers.l2HasCarrier("eth4") and optical.getWanType() == "GPHY4") and current ~= "ETH" then
        logger:notice("Changing to ETH From " .. current)
        return "L2Sense"
      end
    end
  -- to handle priority WAN connection type for VBNT-K
  else
    if scripthelpers.l2HasCarrier("eth4") and (current == "ETH" or current == "SFP") then
      return "L3UpSense"
    elseif scripthelpers.l2HasCarrier("eth4") and (current ~= "ETH" and current ~= "SFP") then
      logger:notice("Changing to ETH From " .. current)
      return "L2Sense"
    else
      if mode then
        if match(mode, "ATM") and current ~= "ADSL" then
          logger:notice("Changing to ADSL From " .. current)
          return "L2Sense"
        elseif match(mode, "PTM") and current ~= "VDSL" then
          logger:notice("Changing to VDSL From " .. current)
          return "L2Sense"
        end
      elseif scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
        return "L2Sense"
      end
    end
  end

  --DR If WAN is not up at this point all L2 is Ok so the switch back to L3Sense to turn on the wwan interface
  if s_variant or (not s_variant and not scripthelpers.checkIfInterfaceIsUp("wan")) then
    return "L3Sense"
  elseif not s_variant then
    return "L3UpSense"
  end
end

return M



