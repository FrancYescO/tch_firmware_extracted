#!/usr/bin/lua

-- local dbg = io.open("/tmp/sle.txt", "w") -- "a" for full logging

local ubus = require('ubus')
local uloop = require('uloop')
local uci = require('uci')
local lcur=uci.cursor()
local lfs=require('lfs')
local ledcfg='ledfw'
lcur:load(ledcfg)
local info_service_led_timeout, service_led_if_mobile, statusled_enabled, statusled_delayed, err

info_service_led_timeout,err=lcur:get(ledcfg,'timeout','ms')
if info_service_led_timeout == nil then
   info_service_led_timeout=3000
else
   info_service_led_timeout=tonumber(info_service_led_timeout)
end

service_led_if_mobile,err = lcur:get(ledcfg,'status_led','mobile_itf')
if service_led_if_mobile == nil then
	service_led_if_mobile = true
elseif service_led_if_mobile == '0' then
	service_led_if_mobile = false
else
	service_led_if_mobile = true
end

statusled_enabled, err = lcur:get(ledcfg,'status_led','enable')
statusled_enabled = (not statusled_enabled or statusled_enabled == '1')
statusled_delayed, err = lcur:get(ledcfg,'status_led','delayed')
statusled_delayed = statusled_delayed == '1'

local wifi_on = {}
local eco_mode = false
local eco_blue_LED = lfs and lfs.attributes("/sys/class/leds/power:blue/", "mode") == "directory"
local infobutton_pressed = false

local voice = "unknown"
local voiceEnabled = ""

local services = {
--  service_name initial_state
    internet = false,
    iptv = false,
    voip = false
}

uloop.init()
local conn = ubus.connect()
if not conn then
    error("Failed to connect to ubusd")
end

local events = {}

-- voice can be ENABLED RUNNING or NAsomething.  NA@ means NOT AVAILABLE see /etc/inet.d/mmpbxd
local function is_service_ok()

    local service_ok = true
    local ignorevoip = false
    if not services.voip then
        local profileEnabled
        local voiceEnabled

        local voice_cursor = uci.cursor()
        voice_cursor:foreach("mmpbxrvsipnet", "profile", function(s)
          profileEnabled = s['enabled']
          if profileEnabled == "1" then
             return false
          end
        end)
        voice_cursor:load("mmpbx")
        voiceEnabled = voice_cursor:get("mmpbx", "global","enabled")
        voice_cursor:close()
        ignorevoip = (voiceEnabled ~= '1') or (profileEnabled ~= '1')
    end
    lcur:load(ledcfg)
	local ledfw=lcur:get_all(ledcfg)

    for k, v in pairs(services) do
        if v == false then
            if ( k ~= "voip" or not ignorevoip) and (ledfw == nil or ledfw[k]==nil or ledfw[k]['check']==nil or ledfw[k]['check']=='1') then
                -- If at least one service is nok then the status led should be red
                service_ok = false
                break
            end
        end
    end
    return service_ok
end

local statusled_active_delay = uloop.timer(function() send_status_led(true, false);end)
local function send_status_led(active, delayed)
    local packet = {}
    if active then 
        packet["state"] = "active"
    else
        statusled_active_delay:cancel()
        statusled_active_delay = uloop.timer(function() send_status_led(true, false);end)
        packet["state"] = "inactive"
    end
    if active and delayed then 
       -- Setup a timer
       if info_service_led_timeout > 0 and statusled_enabled then
           statusled_active_delay:cancel()
           statusled_active_delay = uloop.timer(function() send_status_led(true, false);end)
           statusled_active_delay:set(info_service_led_timeout)
       end
    else
        conn:send("statusled", packet)
    end
end

local function ledaction(delayed_status_led_active)
    if is_service_ok() == false then
        local packet = {}
        send_status_led(false,false)
        packet["state"] = "service_notok"
        conn:send("power", packet)
    else
        local packet = {}
        if infobutton_pressed == false then
            send_status_led(info_service_led_timeout > 0 and statusled_enabled, delayed_status_led_active)
        end
        if eco_mode == true then
            packet["state"] = "service_eco"
        else
            packet["state"] = "service_fullpower"
        end
        conn:send("power", packet)
    end
end

local function info_timeout()
    local packet = {}
    if is_service_ok() == true then
        packet["state"] = "active"
        conn:send("statusled", packet)
        if eco_mode == true then
            packet["state"] = "service_eco"
        else
            packet["state"] = "service_fullpower"
        end
        conn:send("power", packet)
    else
        packet["state"] = "inactive"
        conn:send("statusled", packet)
        packet["state"] = "service_notok"
        conn:send("power", packet)
    end
    infobutton_pressed = false
end

events['infobutton'] = function(msg)
    if msg ~= nil and msg.state == "active" and infobutton_pressed == false then
        local packet = {}
        packet["state"] = "inactive"
        conn:send("statusled", packet)
        -- Setup a timer
        if info_service_led_timeout > 0 and statusled_enabled then
            infobutton_pressed = true
            local timer = uloop.timer(info_timeout)
            timer:set(info_service_led_timeout)
        end
    end
end

events['statusled'] = function(msg)
    if msg then
        if msg.state == "enabled" then
           statusled_enabled = true
           lcur:load(ledcfg)
           info_service_led_timeout, err = lcur:get(ledcfg,'timeout','ms')
           if info_service_led_timeout == nil then
              info_service_led_timeout=3000
           else
              info_service_led_timeout=tonumber(info_service_led_timeout)
           end
        elseif msg.state == "disabled" then
           statusled_enabled = false
        end
        ledaction()
    end
end


events['wireless.wlan_led'] = function(msg)
    local new_eco_value = true
    local wifi_state = false

    if msg == nil or msg.ifname == nil then
        return
    end

    if msg.radio_oper_state == 1 and msg.bss_oper_state == 1 then
        wifi_state = true
    elseif msg.radio_oper_state == 0 and msg.bss_oper_state == 0 then
        wifi_state = false
    end
    wifi_on[msg.ifname] = wifi_state

    if not eco_blue_LED then return end
    for k, v in pairs(wifi_on) do
        if v then
            new_eco_value = false
        end
    end
    if new_eco_value ~= eco_mode then
        eco_mode = new_eco_value
        ledaction()
    end
end

if services.broadband ~= nil then
    events['xdsl'] = function(msg)
        local new_value = false
        if msg ~= nil and  msg.statuscode == 5 then
            new_value = true
        else
            new_value = false
        end
        if new_value ~= services.broadband then
            services.broadband = new_value
            ledaction(statusled_delayed)
        end
    end
end

local internet_wwan=false
local internet_wan=false
if services.internet ~= nil or services.iptv ~= nil then
    local internet_new_value
    local iptv_new_value = false
    local do_action = false
    events['network.interface'] = function(msg)
        if msg ~= nil and msg.interface ~= nil and msg.action ~= nil then
            local internet_event_arrived = false
            local itf_action = msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_')
            if itf_action == "wan_ifup" then
                internet_wan = true
                internet_event_arrived = true
            elseif itf_action == "wwan_ifup" then
                internet_wwan = true
                internet_event_arrived = true
            elseif itf_action == "wan_ifdown" then
                internet_wan = false
                internet_event_arrived = true
            elseif itf_action == "wwan_ifdown" then
                internet_wwan = false
                internet_event_arrived = true
--          elseif itf_action == "broadband_ifdown" then
--              internet_new_value = false
--              internet_event_arrived = true
            end
            internet_new_value = internet_wan or ( internet_wwan and service_led_if_mobile )
            if services.internet ~= nil and internet_event_arrived and internet_new_value ~= services.internet then
                services.internet = internet_new_value
                do_action = true
            end

            local iptv_event_arrived = false
            if msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_') == "iptv_ifup" then
                iptv_new_value = true
                iptv_event_arrived = true
            elseif msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_') == "iptv_ifdown" then
                iptv_new_value = false
                iptv_event_arrived = true
            else
                iptv_event_arrived = false
            end
            if services.iptv ~= nil and iptv_event_arrived and iptv_new_value ~= services.iptv then
                services.iptv = iptv_new_value
                do_action = true
            end
            if do_action then
                ledaction(statusled_delayed)
            end
        end
    end
end

if services.voip ~= nil then
    local voip_component = {
        fxs = false,
        dect = false
    }
    events['mmpbx.profilestate'] = function(msg)
        if msg ~= nil then
--          /etc/init.d/mmpbxd sends messages see /etc/init.d/mmpbxd
--          dbg:write(tostring(msg.voice), ": voice\n")
            if msg.voice ~= nil and msg.voice ~= "" then
                voice = msg.voice
                if voice == "ENABLED" then
                    voiceEnabled = voice
             --noProfileEnabled set to true each time mmpbx is enabled
                    noProfileEnabled = true
                end
                ledaction(statusled_delayed)
            end
        end
    end

    events['mmpbx.profile.status'] = function(msg)
        if msg ~= nil and msg.enabled == "1" then
            noProfileEnabled = false
        end
    end

    events['mmpbx.voiceled.status'] = function(msg)
        if msg ~= nil and msg.fxs_dev_0 ~= "IDLE" then
            if (msg.fxs_dev_0 == "NOK" or msg.fxs_dev_1 == "NOK") then
                voip_component.fxs = false
            else
                voip_component.fxs = true
            end
            if (voip_component.dect or voip_component.fxs) ~= services.voip then
                services.voip = (voip_component.dect or voip_component.fxs)
                ledaction(statusled_delayed)
            end
        end
    end

    events['mmpbx.dectled.status'] = function(msg)
        if msg ~= nil then
            if msg.dect_dev ~= nil then
                if (msg.dect_dev == "unregistered_usable"
                    or msg.dect_dev == "registered_usable"
                    or msg.dect_dev == "registering_usable") then
                    voip_component.dect = true
                else
                    voip_component.dect = false
                end
                if (voip_component.dect or voip_component.fxs) ~= services.voip then
                    services.voip = (voip_component.dect or voip_component.fxs)
                    ledaction(statusled_delayed)
                end
            end
            -- dbg:flush()
        end
    end
end
conn:listen(events)

uloop.run()
