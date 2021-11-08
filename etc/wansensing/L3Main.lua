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

--Update hotspot NAS IP
local function updateNasIp(runtime)
    local scripthelpers = runtime.scripth
    local conn = runtime.ubus
    local x = runtime.uci.cursor()
    local logger = runtime.logger

    local ipv4addr = scripthelpers.checkIfInterfaceHasIP("wan", false)
    local nas_wan_ip = x:get("wireless", "ap7", "nas_wan_ip")
    if ipv4addr and nas_wan_ip ~= ipv4addr then
        logger:notice("update nas ip to " .. ipv4addr)
        x:set("wireless", "ap7", "nas_wan_ip", ipv4addr)
        x:commit("wireless")
        conn:call("wireless", "reload", { })
    end
end

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
                --Update hotspot NAS IP
                updateNasIp(runtime)
                -- Disable mobile
                failoverhelper.mobiled_enable(runtime, "0")
                handle_wan_event(runtime, "network_interface_wan_ifup")
            end
        end
        return "L3Sense"
    elseif event == "network_interface_wan_ifup" then
        --Update hotspot NAS IP
        updateNasIp(runtime)
        -- Disable mobile
        failoverhelper.mobiled_enable(runtime, "0")

        handle_wan_event(runtime, event)
        return "L3Sense"
    elseif event == "network_interface_wan_ifdown" then
        handle_wan_event(runtime, event)
        if mode == "auto" then
            -- Enable mobile
            failoverhelper.mobiled_enable(runtime, "1")
        end
        return "L3Sense"
    end
end

return M

