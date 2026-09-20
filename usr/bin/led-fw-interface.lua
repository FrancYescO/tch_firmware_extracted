#!/usr/bin/env lua

local ubus, uloop = require('ubus'), require('uloop')

uloop.init()

local conn = ubus.connect()
if not conn then
    error("Failed to connect to ubusd")
end

local events = {}
------------------------------------------------------DECT section -------------------------------------------------------
events['mmpbxbrcmdect.status'] = function(data)
if data ~= nil then

local dectRegistered = false
local dectUsable = false

 --extrat the 2 tables: registration & mappingStatus
  local regData = data.registration
  local mappingStatus = data.mappingStatus
  local isOngoing = tostring(regData.isOngoing)

  for device, status in pairs (mappingStatus) do
  --to consider the dect registered, at least one dect device should be registered
  dectRegistered = dectRegistered or (status["deviceRegistered"] == "true")
  --if at least one dect device has a valid mapping (mapped to an active profile => the dect is considered usable)
  dectUsable = dectUsable or
               ((status["deviceActive"] == "true") and (status["incMapStatus"] == "MMMAP_INCMAP_DEVICE_MAPPED_OK" or status["outMapStatus"] == "MMMAP_OUTMAP_DEVICE_MAPPED_OK"))
  end --for

  local regStatus = ""
  if(isOngoing == "true") then
  regStatus = "registering"
  else
    if(dectRegistered == true) then
     regStatus = "registered"
    else
     regStatus = "unregistered"
    end
  end

  local usability = ""
  if(dectUsable == true) then
   usability = "_usable"
  else
   usability = "_unusable"
  end

    local packet = {}
    packet["dect_dev"] = regStatus .. usability
    conn:send("mmpbx.dectled.status", packet)

end
end
conn:listen(events)
--end of DECT section

------------------------------------------------------FXS section -------------------------------------------------------
events['mmbrcmfxs.profile.status'] = function(data)
    if data ~= nil then
        local packet = {}
        for device, status in pairs (data) do
        if ((status["incMapStatus"] == "MMMAP_INCMAP_DEVICE_NOT_MAPPED") and (status["outMapStatus"] == "MMMAP_OUTMAP_DEVICE_NOT_MAPPED")) then
            packet[device] = "OK-OFF"
        elseif ((status["incMapStatus"] == "MMMAP_INCMAP_DEVICE_MAPPED_ERROR") or (status["outMapStatus"] == "MMMAP_OUTMAP_DEVICE_MAPPED_ERROR")) then
            packet[device] = "NOK"
        elseif ((status["incMapStatus"] == "MMMAP_INCMAP_DEVICE_MAPPED_EMERGENCY") or (status["outMapStatus"] == "MMMAP_INCMAP_DEVICE_MAPPED_EMERGENCY")) then
            packet[device] = "OK-EMERGENCY"
        else
            packet[device] = "OK-ON"
        end

        end
   conn:send("mmpbx.voiceled.status", packet)
   end
end
conn:listen(events)
--end of FXS section



while true do
    uloop.run()
end
