#!/usr/bin/lua
local uci = require('uci')
local ubus = require('ubus')
local stop = false
local curtime
local newtime
local difftime
local cursor = uci.cursor()
local timetosleep
local tcmf = cursor:get("tod", "global", "time_change_monfreq")

if tcmf == nil or tcmf == "" then
    timetosleep = 60 -- by default check the time change every minute
else
    timetosleep = tonumber(tcmf)
    if timetosleep <= 0 then
        timetosleep = 60 -- by default check the time change every minute
    end
end

local conn = ubus.connect()
if not conn then
    error("Failed to connect to ubusd")
end

while true do
    curtime = os.time()
    os.execute("sleep " .. timetosleep)
    newtime = os.time()
    difftime = newtime - curtime

    if (difftime ~= timetosleep) then
        conn:send("time.changed", {oldtime = tostring(curtime), newtime = tostring(newtime)})
    end
end 
