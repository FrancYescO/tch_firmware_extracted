local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')
---
-- List all events with will schedule the check method
--   Support implemented for :
--       a) network interface state changes coded as `network_interface_xxx_yyy` (xxx= OpenWRT interface name, yyy = ifup/ifdown)
--       b) dslevents (xdsl_1(=idle)/xdsl_2/xdsl_3/xdsl_4/xdsl_5(=show time))
--       c) network device state changes coded as 'network_device_xxx_yyy' (xxx = linux netdev, yyy = up/down)
-- @SenseEventSet [parent=#M] #table SenseEventSet
M.SenseEventSet = {
    'network_interface_wan_ifup',
    'network_interface_wan_ifdown',
}

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
    local conn = runtime.ubus
    local logger = runtime.logger
    local uci = runtime.uci
    logger:notice("WAN Sensing L3 Checking")

    if not uci or not conn or not logger then
        return false
    end

    local x = uci.cursor()
    local mode = x:get("wansensing", "global", "network_mode")
    logger:notice("The L3 Checking : sensing on l2type=" .. tostring(l2type) .. ",event=" .. tostring(event))
    if event == "timeout"  then
        runtime.sent_intf_up_event = runtime.sent_intf_up_event or 0
        if runtime.sent_intf_up_event < 10 and scripthelpers.checkIfInterfaceIsUp("wan") then
            runtime.sent_intf_up_event = runtime.sent_intf_up_event + 1
            conn:send('interface.up', {})
            logger:notice("Send event interface.up")
        end

        if mode == "Mobiled_scheduled" then
            failoverhelper.tod_config(runtime, "1")
        else
            failoverhelper.tod_config(runtime, "0")
        end
        if mode == "Fixed_line" then
            -- Disable mobile
            failoverhelper.mobiled_enable(runtime, "0")
        end
        if runtime.entry_l3 then
            runtime.entry_l3 = false
            if scripthelpers.checkIfInterfaceIsUp("wan") then
                -- Disable mobile
                failoverhelper.mobiled_enable(runtime, "0")
            end
        end
        return "L3Sense"
    elseif event == "network_interface_wan_ifup" then
        -- Disable mobile
        failoverhelper.mobiled_enable(runtime, "0")
        return "L3Sense"
    elseif event == "network_interface_wan_ifdown" then
        if mode == "auto" then
            -- Enable mobile
            failoverhelper.mobiled_enable(runtime, "1")
        end
        return "L3Sense"
    end
end

return M
