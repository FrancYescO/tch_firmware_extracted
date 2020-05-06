#!/usr/bin/lua

-- local dbg = io.open("/tmp/sle.txt", "w") -- "a" for full logging

local ubus, uloop = require('ubus'), require('uloop')

local wifi_on = {}
local eco_mode = false
local infobutton_pressed = false

local voice = "unknown"
local voiceEnabled = ""

local services = {
--  service_name initial_state
    internet = false,
--    iptv = false,
    voip = false
}

uloop.init()
local conn = ubus.connect()
if not conn then
    error("Failed to connect to ubusd")
end

local events = {}

-- voice can be ENABLED RUNNING or NAsomething.  NA means NOT AVAILABLE see /etc/inet.d/mmpbxd
local function is_service_ok()
    local service_ok = true
    if services.voip == false and string.match(voice, "NA") == "NA" then
        services.voip = true
    end
    for k, v in pairs(services) do
        if v== false then
            -- dbg:write(tostring(k), ": LED false\n") dbg:flush()
            service_ok = false
        end
    end
    return service_ok
end

local function ledaction()
    if is_service_ok() == false then
        local packet = {}
        packet["state"] = "inactive"
        conn:send("statusled", packet)
        packet["state"] = "service_notok"
        conn:send("power", packet)
    else
        local packet = {}
        if infobutton_pressed == false then
            packet["state"] = "active"
            conn:send("statusled", packet)
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
    local new_value = false
    if msg ~= nil and msg.state == "active" and infobutton_pressed == false then
        infobutton_pressed = true
        local packet = {}
        packet["state"] = "inactive"
        conn:send("statusled", packet)
        -- Setup a timer
        local timer = uloop.timer(info_timeout)
        timer:set(3000)
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
    else
        wifi_state = false
    end
    wifi_on[msg.ifname] = wifi_state

    for k, v in pairs(wifi_on) do
        if v == true then
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
        ledaction()
    end
    end
end

if services.internet ~= nil or services.iptv ~= nil then
    local internet_new_value = false
    local iptv_new_value = false
    events['network.interface'] = function(msg)
    if msg ~= nil and msg.interface ~= nil and msg.action ~= nil then
        local internet_event_arrived = false
        if msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_') == "wan_ifup" then
            internet_new_value = true
            internet_event_arrived = true
        elseif msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_') == "wan_ifdown" then
            internet_new_value = false
            internet_event_arrived = true
--        elseif msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_') == "broadband_ifdown" then
--            internet_new_value = false
--            internet_event_arrived = true
        else
            internet_event_arrived = false
        end
        if services.internet ~= nil and internet_event_arrived and internet_new_value ~= services.internet then
            services.internet = internet_new_value
            ledaction()
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
            ledaction()
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
        -- /etc/init.d/mmpbxd sends messages see /etc/init.d/mmpbxd
        -- dbg:write(tostring(msg.voice), ": voice\n")
        if msg.voice ~= nil and msg.voice ~= "" then
            voice = msg.voice
            if voice == "ENABLED" then
                voiceEnabled = voice
            end
            ledaction()
        end
    end
    end

    events['mmpbx.voiceled.status'] = function(msg)
    if msg ~= nil then
        if (msg.fxs_dev_0 ~= "" and msg.fxs_dev_1 ~= "") then
            if (msg.fxs_dev_0 == "true" and msg.fxs_dev_1 == "true") then
                voip_component.fxs = true
            else
                voip_component.fxs = false
            end
        elseif (msg.fxs_dev_0 == "" and msg.fxs_dev_1 ~= "") then
            if (msg.fxs_dev_1 == "true") then
                voip_component.fxs = true
            else
                voip_component.fxs = false
            end
        elseif (msg.fxs_dev_1 == "" and msg.fxs_dev_0 ~= "") then
            if (msg.fxs_dev_0 == "true") then
                voip_component.fxs = true
            else
                voip_component.fxs = false
            end
        elseif (msg.fxs_dev_0 == "" and msg.fxs_dev_1 == "") then
            voip_component.fxs = true
        else
            voip_component.fxs = false
        end
        if (voip_component.dect or voip_component.fxs) ~= services.voip then
            services.voip = (voip_component.dect or voip_component.fxs)
            ledaction()
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
            ledaction()
        end
        end
        -- dbg:flush()
    end
    end

end
conn:listen(events)

uloop.run()
