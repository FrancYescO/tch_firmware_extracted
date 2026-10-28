local ubus, uloop, uci = require('ubus'), require('uloop'), require('uci')
local netlink = require("tch.netlink")
local format = string.format
--local dbg = io.open("/tmp/sle.txt", "w") -- "a" for full logging

local M = {}

local config = "ledfw"
local cursor = uci.cursor()
local linkstatus = "down"

cursor:load(config)
local info_service_led_timeout, err = cursor:get(config, 'timeout', 'ms')
if info_service_led_timeout == nil then
    info_service_led_timeout = 2000
end

cursor:unload(config)

local wan_status = "initial"


--Led runtime data structure:
-- broadband
--    status: initial, off, no_line, sync, ip_connected, ping_ok, ping_ko, upgrade_ko, upgrade_ongoing.
--    mode: initial, persistent, timerled.
--    color: refers to definition in statemachine.
--    utimer: uloop timer instance.
-- wireless
--    status: initial, off, radio_off, channel_analyzing, not_best_channel, best_channel.
--    mode: initial, persistent, timerled.
--    color: refers to definition in statemachine.
--    utimer: uloop timer instance.
-- wps
--    status: initial, off, wifi_on, wps_ongoing, wps_ko, wps_ok.
--    mode: initial, persistent, timerled.
--    color: refers to definition in statemachine.
--    utimer: uloop timer instance.
local led = {
    broadband = {status = "initial", mode = "initial", color = "none", utimer = nil},
    wireless = {status = "initial", mode = "initial", color = "none", utimer = nil},
    wps = {status = "initial", mode = "initial", color = "none", utimer = nil},
}

cursor:load("wireless")
local wl0_state, err = cursor:get('wireless', 'radio_2G', 'state')
local wl1_state, err = cursor:get('wireless', 'radio_5G', 'state')
local wifi = {
    wl0 = {state = wl0_state},
    wl1 = {state = wl1_state},
}
cursor:unload("wireless")

local reset_timer = nil
local reset_timeout = 10000

local function export_led_color(ledname, color)
    led[ledname].color = color

    cursor:load("ledfw")
    if (cursor:get("ledfw", ledname, "status") == nil) then
        cursor:set("ledfw", ledname, "led")
    end
    
    cursor:set("ledfw", ledname, "status", led[ledname].status)

    if led[ledname].status == "off" then
        cursor:set("ledfw", ledname, "color", "off")
    else
        cursor:set("ledfw", ledname, "color", color)
    end

    cursor:commit("ledfw")
    cursor:unload("ledfw")
end

local function led_timer_cb(ledname, cb)
    --dbg:write(ledname, ": led_timeout\n")
    --dbg:flush()

--    status: initial, off, no_line, sync, ip_connected, ping_ok, ping_ko, upgrade_ko, upgrade_ongoing.
    if ledname == "broadband" then
        if led[ledname].status ~= "initial" and led[ledname].status ~= "off" and led[ledname].status ~= "no_line" and led[ledname].status ~= "sync" and led[ledname].status ~= "upgrade_ongoing" then
            led[ledname].status = "off"
            cb(ledname..'_led_timeout')
        end
    else
        led[ledname].status = "off"
        cb(ledname..'_led_timeout')
    end

    export_led_color(ledname, "off")
end

local function update_led_status(cb, ledname, status, mode, color)
    --dbg:write(ledname.." "..status.." "..mode.." "..color, ": update_led_status\n")
    --dbg:flush()

    -- In fastweb definition, there is no chance to directly set led 'off', but only timeout 'off'.
    -- So, only process '~off' status here, while 'off' is processed in timer callback.
    
    if mode == "timerled" then
        -- set timer to turn off this led after 5s
        if led[ledname].utimer == nil then
            led[ledname].utimer = uloop.timer(function() led_timer_cb(ledname, cb) end, info_service_led_timeout)
        else
            --refresh timeout value
            led[ledname].utimer:set(info_service_led_timeout)
        end
    elseif mode == "persistent" and led[ledname].utimer ~= nil then
        led[ledname].utimer:cancel()
        led[ledname].utimer = nil
    end

    led[ledname].status = status
    led[ledname].mode = mode

    export_led_color(ledname, color)
end

function M.start(cb)
    uloop.init()
    local conn = ubus.connect()
    if not conn then
        error("Failed to connect to ubusd")
    end

    local events = {}

    events['network.interface'] = function(msg)
        if msg ~= nil and msg.interface ~= nil then
            local wanevent = false
            if msg.action ~= nil and msg.interface == "wan" then
                if msg.action:gsub('[^%a%d_]','_') == "ifup" then
                    wan_status = "ifup"

                    cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. 'ifup')
                    wanevent = true
                else
                    wan_status = "ifdown"
                    cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_'))
                    wanevent = true
                end
            end

            if msg.interface:match('^wan6?$') ~= nil then
                if (msg['ipv4-address'] ~= nil or msg['ipv6-address'] ~= nil) then 
                   if (msg['ipv4-address'] == nil or msg['ipv4-address'][1] == nil) and (msg['ipv6-address'] == nil or msg['ipv6-address'][1]== nil) then
                      cb('network_interface_' .. msg.interface .. '_no_ip')
                   end
                end
            end

            if msg.pppinfo ~= nil  and msg.pppinfo.pppstate ~= nil then
                cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_ppp_' .. msg.pppinfo.pppstate:gsub('[^%a%d_]','_'))
            end

            if wanevent == true then
                if msg.action:gsub('[^%a%d_]','_') == "ifup" then
                    if led.broadband.status == "no_line" or led.broadband.status == "sync" then
                      -- set timer to turn off this led after 5s
                      update_led_status(cb, "broadband", "ip_connected", "persistent", "green-solid")
                    end
                else
                    -- layer3 down, doesn't timeout led
                    update_led_status(cb, "broadband", "sync", "persistent", "red-blink")
                end
            end
        end
    end 

    events['xdsl'] = function(msg)
        if msg ~= nil then
            cb('xdsl_' .. msg.statuscode)

            local xdslcode = tonumber(msg.statuscode)
            if (xdslcode >= 1 and xdslcode <= 4) or (xdslcode == 6) then
                update_led_status(cb, "broadband", "sync", "persistent", "red-blink")
                linkstatus = "up"
            elseif xdslcode == 0 then
                update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                linkstatus = "down"
            end
        end
    end

    events['gpon.ploam'] = function(msg)
        if msg ~= nil and msg.statuscode ~= nil then
            if msg.statuscode ~= '5' then
                cb('gpon_ploam_' .. msg.statuscode)
                local gponcode = tonumber(msg.statuscode)
                if gponcode >= 1 and gponcode <= 8 then
                    if gponcode >= 2 and gponcode <= 4 then
                        update_led_status(cb, "broadband", "sync", "persistent", "red-blink")
                        linkstatus = "up"
                    else
                        update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                        linkstatus = "down"
                    end
                end
            else
                cb('gpon_ploam_50')
                update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                linkstatus = "down"
            end
        end
    end

    events['gpon.omciport'] = function(msg)
        if msg ~= nil and msg.statuscode ~= nil then
            cb('gpon_ploam_5' .. msg.statuscode)
            if msg.statuscode == '0' then
                update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                linkstatus = "down"
            end
        end
    end

    events['line.button'] = function(msg)
        if msg ~= nil and led.broadband.status == "off" or led.broadband.status == "ip_connected" or led.broadband.status == "ping_ok" or led.broadband.status == "ping_ko" then
            if msg.lineinfo == "ping OK" then
                cb('ping_success')
                update_led_status(cb, "broadband", "ping_ok", "timerled", "green-blink")
            elseif msg.lineinfo == "ping KO" then
                cb('ping_failed')
                update_led_status(cb, "broadband", "ping_ko", "timerled", "red-blink")
            end

        end
    end

    events['wireless.wlan_led'] = function(msg)
        if msg ~= nil then
            if msg.radio_oper_state == 1 and msg.bss_oper_state == 1 then
               if msg.ifname == "wl0" then
                   wifi.wl0.state = 1
               elseif msg.ifname == "wl1" then
                   wifi.wl1.state = 1
               end

               cb('wifi_radio_on')
            elseif msg.radio_oper_state == 0 and msg.bss_oper_state == 0 then
               if msg.ifname == "wl0" then
                   wifi.wl0.state = 0
               elseif msg.ifname == "wl1" then
                   wifi.wl1.state = 0
               end

               if wifi.wl0.state == 0 and wifi.wl1.state == 0 then
                   cb("wifi_both_radio_off")
               end
            end
        end
    end

    events['wireless.wps_led'] = function(msg)
        if msg ~= nil and msg.wps_state ~= nil then
            if led.wps.status == "wps_ongoing" then
                if string.match(msg.wps_state, "success") == "success" then
                    cb('wps_registration_success')
                    update_led_status(cb, "wps", "wps_ok", "timerled", "green-solid")
                elseif (string.match(msg.wps_state, "idle") == "idle") or (string.match(msg.wps_state, "error") == "error") or (string.match(msg.wps_state, "off") == "off") or (string.match(msg.wps_state, "session_overlap") == "session_overlap") then
                    cb('wps_registration_fail')
                    update_led_status(cb, "wps", "wps_ko", "timerled", "red-solid")
                end
            elseif string.match(msg.wps_state, "inprogress") == "inprogress" then
                cb('wps_registration_ongoing')
                update_led_status(cb, "wps", "wps_ongoing", "persistent", "green-blink")
            end
        end
    end

    events['fwupgrade'] = function(msg)
        if msg ~= nil and msg.state ~= nil and led.broadband.status ~= "initial" then
            cb("fwupgrade_state_" .. msg.state)

            if msg.state == "failed" then
                update_led_status(cb, "broadband", "upgrade_ko", "timerled", "red-blink")
            elseif msg.state == "upgrading" then
                update_led_status(cb, "broadband", "upgrade_ongoing", "persistent", "green-blink")
            end
        end
    end

    events['system.startup'] = function(msg)
        if msg ~= nil and msg.state ~= nil and led.broadband.status == "initial" then
            cb("system_startup_" .. msg.state)
            -- If there is no other broadband led event untill system startup, we regard there is no wan line.
            update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
        end
    end

    events['reset.button'] = function(msg)
        if msg ~= nil and msg.action ~= nil then
            if msg.action == "pressed" then
                -- Changes to 'reset_prepare' pattern, so that line led can go its prior status if reset aborted.
                -- Broadband led status will be controlled according to pattern when reset pressed, don't change its status.

                if led.broadband.status ~= "initial" then
                    cb('reset_prepare')
                end

                reset_timer = uloop.timer(function() cb('reset_ongoing') end, reset_timeout)
            elseif msg.action == "released" then
                if string.match(msg.resetinfo, "factory") == "factory" then
                    -- Broadband led status will be controlled according to pattern when reset pressed, don't change its status.
                    -- Ambient led has been set during the pre-condition pattern 'reset_prepare', no need to reset here.
                    cb('reset_ongoing')
                elseif string.match(msg.resetinfo, "abort") == "abort" or string.match(msg.resetinfo, "complete") == "complete" then
                    cb('reset_noaction')
                    reset_timer:cancel()
                    reset_timer = nil
                end
            end
        end 
    end

    events['sfp'] = function(msg)
        if msg ~= nil and msg.status ~= nil then
            if string.match(msg.status, "tx_enable") == "tx_enable" then
                if wan_status == "ifup" then
                    if led.broadband.status == "no_line" or led.broadband.status == "sync" then
                        cb('network_interface_wan_ifup')
                        update_led_status(cb, "broadband", "ip_connected", "persistent", "green-solid")
                    end
                elseif wan_status == "ifdown" then
                    cb('network_device_eth_wan_ifup')
                    update_led_status(cb, "broadband", "sync", "persistent", "red-blink")
                end

                linkstatus = "up"
            elseif string.match(msg.status, "tx_disable") == "tx_disable" then
                cb('network_device_eth_wan_ifdown')
                update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                linkstatus = "down"
            end
        end
    end

    conn:listen(events)

    --register for netlink events
    local nl,err = netlink.listen(function(dev, status)
        cursor:load("network")
        local broadband_ifname = nil

        broadband_ifname = cursor:get("network", "wan", "ifname")
        if broadband_ifname ~= nil and string.sub(broadband_ifname, 1, 1) == '@' then
          local at_intf = string.sub(broadband_ifname, 2, -1)
          if at_intf ~= nil then
            broadband_ifname = cursor:get("network", at_intf, "ifname")
          end
        end

        -- Eth4 status represents SFP module.
        -- Other eth interface is possible to be set as WAN interface also according to fastweb.
        if (string.match(dev, "eth") == "eth" and broadband_ifname ~= nil and dev == broadband_ifname) then
            if status then
                if led.broadband.status == "initial" or led.broadband.status == "no_line" then
                    cb('network_device_eth_wan_ifup')
                    update_led_status(cb, "broadband", "sync", "persistent", "red-blink")
                    linkstatus = "up"
                end
            else
                cb('network_device_eth_wan_ifdown')
                update_led_status(cb, "broadband", "no_line", "persistent", "red-solid")
                linkstatus = "down"
            end

        end
        cursor:unload("network")
    end)

    if not nl then
        error("Failed to register with netlink" .. err)
    end

    uloop.run()
end

return M
