#!/usr/bin/env lua
-- Copyright (c) 2018 Technicolor

local uci = require("uci")
local cursor = uci.cursor()
local unlock_state = cursor:get("env","var","unlockedstatus")
local unlockGUIButton = cursor:get("env","var","unlockGUIbutton")
if unlock_state == "1" and unlockGUIButton == "1" then
   cursor:set("cwmpd", "cwmpd_config", "state", "0")
   --sleep of 10 seconds is introduced so that cwmpd is disabled after active notification(for param 'X_TELECOMITALIA_IT_Unlocked') is sent to ACS.
   os.execute("sleep 10")
elseif unlockGUIButton == "1" then
   cursor:set("cwmpd", "cwmpd_config", "state", "1")
end
cursor:commit("cwmpd")
os.execute("/etc/init.d/cwmpd reload")
