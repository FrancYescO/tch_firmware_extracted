#!/usr/bin/env lua

local ubus, uloop = require('ubus'), require('uloop')
local voiceled = require("ledframework.voiceled")

uloop.init()

local conn = ubus.connect()
if not conn then
    error("Failed to connect to ubusd")
end

-- Listen to dect registered event
local dect_registration_status = "false"
local dect_registration_ongoing = "false"
local events = {}
events['mmpbxbrcmdect.registered'] = function(msg)
    if msg ~= nil then
        dect_registration_status = tostring(msg.present)
    end
end
events['mmpbxbrcmdect.registration'] = function(msg)
    if msg ~= nil then
        dect_registration_ongoing = tostring(msg.open)
    end
end
conn:listen(events)

local timer
local function polling()

    -- This part of the code is a workaround.
    -- It is due to that mmpbx.device.*.profileUsable value is empty when the board is in FXO-mode.
    -- So here we check whether fxomode is enabled and usable.
    -- This workaround should be removed after NG-20547 is fixed.
    local profile_valid = {}
    local data = conn:call("mmpbx.profile", "get", {})
    if data ~= nil then
        for profile, status in pairs (data) do
            profile_valid[profile] = ((status["enable"] == "true") and (status["usable"] == "true"))
        end
    end

    local data = conn:call("mmpbx.device", "get", {})
    if data ~= nil then
        local packet = {}
        local dectstatus
        local dect_device_status = false

        for device, status in pairs (data) do
            if (device == "fxs_dev_0") or (device == "fxs_dev_1") then
                packet[device] = voiceled.getFxsDeviceLedStatus(device, status, profile_valid)
            end
            if (device == "dect_dev_0")
                or (device == "dect_dev_1")
                or (device == "dect_dev_2")
                or (device == "dect_dev_3")
                or (device == "dect_dev_4")
                or (device == "dect_dev_5") then
                -- This fxo related part should be removed after NG-20547 is fixed
                if profile_valid["fxo_profile"] == true then
                    dect_device_status = (dect_device_status or (status["deviceUsable"] == true))
                else
                    dect_device_status = (dect_device_status or ((status["deviceUsable"] == true) and (status["profileUsable"] == "true")))
                end
            end
        end

        if dect_registration_ongoing == "true" then
            dectstatus = "registering"
        elseif dect_registration_status == "false" then
            dectstatus = "unregistered"
        else
            dectstatus = "registered"
        end
        if dect_device_status == false then
            dectstatus = dectstatus .. "_unusable"
        else
            dectstatus = dectstatus .. "_usable"
        end
        packet["dect_dev"] = dectstatus
        conn:send("mmpbx.profilestate", packet)
    end
    timer:set(500)
end

timer = uloop.timer(polling)
timer:set(1000)

while true do
    uloop.run()
end
