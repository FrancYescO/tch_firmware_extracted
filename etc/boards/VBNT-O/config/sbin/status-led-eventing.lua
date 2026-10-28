#!/usr/bin/lua

-- local dbg = io.open("/tmp/sle.txt", "w") -- "a" for full logging

local ubus, uloop, uci = require('ubus'), require('uloop'), require('uci')
local lcur=uci.cursor()
local ledcfg='ledfw'
lcur:load(ledcfg)
local info_system_startup_duration, err = lcur:get(ledcfg, 'startup', 'ms')
--cursor:close()
lcur:unload(ledcfg)

if info_system_startup_duration == nil then
    -- assume line event pops up within 16s from the moment ledfw initialized, otherwise no line.
    info_system_startup_duration = 16000
end

uloop.init()

local conn = ubus.connect()
if not conn then
    error("Failed to connect to ubusd")
end

local function startup_complete()
    local packet = {}
    packet["state"] = "complete"
    conn:send("system.startup", packet)
end

local startup_timer = uloop.timer(function() startup_complete() end, info_system_startup_duration)

local events = {}

conn:listen(events)

uloop.run()
