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

lf.start(ledconfig, patternconfig)

