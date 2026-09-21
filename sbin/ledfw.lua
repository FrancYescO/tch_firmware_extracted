#!/usr/bin/lua
local setmetatable,assert,pcall,setfenv,loadfile = setmetatable,assert,pcall,setfenv,loadfile

local lf = require('ledframework')
local helper = require('ledframework.ledhelper')

-- load and run a script in the provided environment
-- returns the modified environment table
function run(scriptfile)
    local env = setmetatable({}, {__index=helper})
    assert(pcall(setfenv(assert(loadfile(scriptfile)), env)))
    setmetatable(env, nil)
    return env.stateMachines, env.patterns
end

local ledconfig, patternconfig = run('/etc/ledfw/stateMachines.lua')

-- tune the lua garbage collector to be more aggressive and reclaim memory sooner
-- default value of setpause is 200, set it to 100
collectgarbage("setpause",100)
collectgarbage("collect")
collectgarbage("restart")

lf.start(ledconfig, patternconfig)

