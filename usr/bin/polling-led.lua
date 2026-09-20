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
local dect_final_status = false

local events = {}
events['mmpbxbrcmdect.registered'] = function(msg)
    if msg ~= nil then
        dect_registration_status = tostring(msg.present)
    end
end
events['mmpbxbrcmdect.registration'] = function(msg)
local packet = {}
    if msg ~= nil then
        dect_registration_ongoing = tostring(msg.open)

        if dect_registration_ongoing == "true" then
            dectstatus = "registering"
        elseif dect_registration_status == "false" then
            dectstatus = "unregistered"
        else
            dectstatus = "registered"
        end
       if dect_final_status == false then
            dectstatus = dectstatus .. "_unusable"
        else
            dectstatus = dectstatus .. "_usable"
        end

        packet["dect_dev"] = dectstatus
        conn:send("mmpbx.dectled.status", packet)

    end
end
conn:listen(events)



events['mmbrcmfxs.profile.status'] = function(data)
    if data ~= nil then
          local packet = {}
             for device, status in pairs (data) do
                    if status["profileEnabled"] == "false" then
                        packet[device] = "disabled"
                    else
                        packet[device] = status["deviceActive"] and status["profileActive"]
                    end
        end
        conn:send("mmpbx.voiceled.status", packet)
    end
end

events['mmpbxbrcmdect.profile.status'] = function(data)
   local dectstatus
   local dect_device_status = false
   if data ~= nil then
          local packet = {}
             for device, status in pairs (data) do
                  dect_device_status = (dect_device_status or ((status["deviceActive"] == "true") and (status["profileActive"] == "true")))
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
        dect_final_status = dect_device_status
        packet["dect_dev"] = dectstatus
        conn:send("mmpbx.dectled.status", packet)
    end
end
conn:listen(events)



while true do
    uloop.run()
end
