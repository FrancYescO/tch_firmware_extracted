#!/usr/bin/env lua
-- Copyright (c) 2018 Technicolor

local uci = require("uci")
local cursor = uci.cursor()
local unlock_state = cursor:get("env","var","unlockedstatus")
local unlockGUIButton = cursor:get("env","var","unlockGUIbutton")
if unlock_state == "1" and unlockGUIButton == "1" then
   cursor:set("cwmpd", "cwmpd_config", "state", "0")
elseif unlockGUIButton == "1" then
   cursor:set("cwmpd", "cwmpd_config", "state", "1")
end
cursor:commit("cwmpd")
