local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')
local api = require("/etc/wansensing/common_api")
local process = require("tch.process")
local match = string.match

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

local device

local function notify_adb(inf, action)
    -- be sure the lighttpd exists before send the event
    os.execute("var=100; while true; do ps | grep -v grep | grep lighttpd > /dev/null && curl http://localhost:8889/wanstatus?status=".. action .. " && break; var=$((var - 1)); [ $var = 0 ] && break; sleep 5; done &")
end

local function handle_wan_event(runtime, event)
    local conn = runtime.ubus
    local logger = runtime.logger
    if event == "network_interface_wan_ifup" then
      local status = conn:call("network.interface", "status", {interface = "wan"}) or {}
      device = status['l3_device']
      if device then
        logger:notice("wan is up. device:"..device)
        notify_adb(device, "up")
      end
    elseif event == "network_interface_wan_ifdown" then
      if device then
        logger:notice("wan is down. device:"..device)
        -- not mix the situation
        -- notify_adb(device, "down")
      end
    end
end

local function setWanConfig(runtime, l2type, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local x = uci.cursor()
    local logger = runtime.logger

    logger:notice("WAN Sensing L3 Checking : setWanConfig")
    if l2type == "ADSL" and transition == "wantag" then
        logger:notice("L3Main::setWanConfig: wantag atm1 is up")
        x:set("network", "wan", "ifname", "atm1")
    end
    if l2type == "VDSL" and transition == "wantag" then
        local iface = x:get("cwmpd", "cwmpd_config", "interface")
        if iface and match(iface, "^mgmt") then
            x:set("network", "mgmt", "ifname", "@vlan_wan")
            logger:notice("L3Main:Fastweb 2PVC/(ADSL loopback) scenario: to be migrated to VDSL Scenario; setting tagged Management Interface")	
        else
            logger:notice("L3Main::setWanConfig: sensed wantag vlan_ptm0 is up")
            x:set("network", "wan", "ifname", "@vlan_wan")
        end
    end
    if l2type == "ETH" and transition == "wantag" then
        logger:notice("L3Main::setWanConfig: vlan_eth4 is up")
        x:set("network", "wan", "ifname", "@vlan_wan_eth4")
    end

    x:set("network", "wantag", "auto", "0")
    x:commit("network")
    conn:call("network", "reload", { })
end

local function checkWan(runtime, l2type)
    local scripthelpers = runtime.scripth
    local logger = runtime.logger
    --sense atm0/ptm0
    if scripthelpers.checkIfInterfaceIsUp("wan") then
        logger:notice("The L3 Checking wan sensed atm0/ptm0 on l2type interface " .. tostring(l2type))
        --Update hotspot NAS IP
        api.updateNasIp(runtime)

        setWanConfig(runtime, l2type, "wan")
        handle_wan_event(runtime, "network_interface_wan_ifup")
        -- Disable mobile
        failoverhelper.mobiled_enable(runtime, "0")
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
        if runtime.entry_l3 then
            runtime.entry_l3 = false
            checkWan(runtime, l2type)
        end
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
        return "L3Sense"
    elseif event == "network_interface_wan_ifup" or event == "network_interface_wantag_ifup" then
        checkWan(runtime, l2type)
        handle_wan_event(runtime, event)
        --Loopback scenario can directly return as no changes need update
        return "L3Sense"
    elseif event == "network_interface_wan_ifdown" then
        handle_wan_event(runtime, event)
        if mode == "auto" then
            -- Enable mobile
            failoverhelper.mobiled_enable(runtime, "1")
        end
        return "L3Sense"
    end
    return "L2Sense"
end

return M
