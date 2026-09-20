#!/usr/bin/lua
local uci = require('uci')
local todfw = require('todfw')

function loadconfig()
    local glb
    local acttb = {}
    local cursor = uci.cursor()

    cursor:foreach("tod", "tod", function(s) glb = s end)
    cursor:foreach("tod", "action", function(s) acttb[s[".name"]] = s end)
    cursor:unload("tod")

    return glb, acttb
end

local global, action = loadconfig()

todfw.start(global, action)

