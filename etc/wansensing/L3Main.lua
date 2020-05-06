local M = {}
local match = string.match
local failoverhelper = require('wansensingfw.failoverhelper')
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
    'network_interface_wantag_ifup',
    'network_interface_wan_ifdown',
}

local function setWanConfig(runtime, l2type, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local x = uci.cursor()
    local logger = runtime.logger

    logger:notice("WAN Sensing L3 Checking : setWanConfig")
    if l2type == "ETH" or l2type == "FIBER" then
	return
    end
    if l2type == "ADSL" and transition == "wantag" then
		logger:notice("L3Main::setWanConfig: wantag atm1 is up")
        x:set("network", "wan", "ifname", "atm1")
    end
    if l2type == "VDSL" and transition == "wantag" then
		logger:notice("L3Main::setWanConfig: sensed wantag vlan_ptm0 is up")
        x:set("network", "wan", "ifname", "@vlan_wan")
    end

    x:set("network", "wantag", "auto", "0")
    x:commit("network")
    conn:call("network", "reload", { })
end

local function checkWan(runtime, l2type, mode)
    local scripthelpers = runtime.scripth
    local logger = runtime.logger
    local conn = runtime.ubus
    local uci = runtime.uci
    local x = uci.cursor()
    --sense atm0/ptm0
    if scripthelpers.checkIfInterfaceIsUp("wan") then
        logger:notice("The L3 Checking wan sensed atm0/ptm0 on l2type interface " .. tostring(l2type))
        setWanConfig(runtime, l2type, "wan")

        if mode ~= "Mobiled_scheduled" then
           -- Disable mobile
           failoverhelper.mobiled_enable(runtime, "0")
        end
        --Update hotspot NAS IP
        local ipaddr = x:get("network", "wan", "ipaddr")
        local nas_wan_ip = x:get("wireless", "ap7", "nas_wan_ip")
        if ipaddr and nas_wan_ip ~= ipaddr then
           x:set("wireless", "ap7", "nas_wan_ip", tostring(ipaddr))
           x:commit("wireless")
           conn:call("wireless", "reload", { })
        end
        return "L3Sense"
    end
    --sense atm1/vdsl_ptm0
    if scripthelpers.checkIfInterfaceIsUp("wantag") then
        logger:notice("The L3 Checking wantag sensed atm1/vlan_ptm0 on l2type interface " .. tostring(l2type))
        setWanConfig(runtime, l2type, "wantag")
        return "L3Sense"
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
            checkWan(runtime, l2type, mode)
        end
        return "L3Sense"
    elseif event == "network_interface_wan_ifup" or event == "network_interface_wantag_ifup" then
        checkWan(runtime, l2type, mode)
        --Loopback scenario can directly return as no changes need update
        return "L3Sense"
    elseif event == "network_interface_wan_ifdown" then
        if mode == "auto" or mode == "Mobiled" then
            -- Enable mobile
            failoverhelper.mobiled_enable(runtime, "1")
        end
        return "L3Sense"
    end
    return "L2Sense"
end

return M
