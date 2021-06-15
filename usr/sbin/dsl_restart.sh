#!/usr/bin/env lua

local lfs = require("lfs")
local ubus = require("ubus")
local conn = ubus.connect()
local next = next
if not conn then return end

local function callOngoing()
    local calls = {}
    calls = conn:call("mmpbx.call", "get", {})
    if type(calls) == "table" then
        if next(calls) ~= nil then
            return true
        end
    end
    return false
end

if lfs.attributes("/tmp/tmp/dsl_restart", "mode") == "file" then
    local random_delay = math.random(1,7200)
    os.execute("sleep " .. random_delay)

    while(callOngoing()) do
        os.execute("sleep 5")
    end

    os.execute("/etc/init.d/xdsl restart;sed -i '/dsl_restart/d' /etc/crontabs/root;rm -rf /tmp/tmp/dsl_restart")
else
    os.execute("sed -i '/dsl_restart/d' /etc/crontabs/root")
end
