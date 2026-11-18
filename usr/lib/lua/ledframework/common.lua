local io = require("io")
local uci = require('uci')
local posix = require("tch.posix")

local openlog = posix.openlog
local M = {}
local ledPath = "/sys/class/leds/"
local ledPaths = {}
local ledAliases = {}
local syslog = posix.syslog

local colors = {"red", "green", "blue", "orange", "magenta", "cyan", "white"}
local lcur=uci.cursor()
local ledcfg='ledfw'
lcur:load(ledcfg)
local syslog_trace, err = lcur:get(ledcfg,'syslog','trace')
lcur:close()

syslog_trace = syslog_trace == '1'

if not syslog_trace then
    syslog=function() end
end
M.syslog = syslog

openlog("ledfw", posix.LOG_PID, posix.LOG_DAEMON)

local brightness = {}

---
-- Get a LED maxinum brightness
-- @function [parent=#common] getMaxBrightness
-- @param #string name led name
function M.getMaxBrightness(name)
    local maxBrightness = 255
    if type(name) == 'function' then name=name() end
    if name then 
       local ledFile = (ledPaths[name] or ledPath) .. (ledAliases[name] or name)
       if lfs.attributes(ledFile, "mode") == "directory" then
           local fd = io.open(ledFile .. "/max_brightness", "r")
           if fd then
              maxBrightness = fd:read("*all")
              fd:close()
           end
       end
    end
    return maxBrightness
end

--- get led brightness
-- @param name led name
-- @param value the brightness value is set from ledhelper api
-- @return brightness value
local function getBrightness(name, value)
    if not next(brightness) then
        return value
    end
    local val
    if name and name ~= '' then
        local ledname, color = string.match(name, "(.+)[:.](.+)")
        if ledname and color then
            local ledtable = brightness[ledname]
            if ledtable and type(ledtable) == "table" and ledtable[color] then
                val = ledtable[color]
            else
                val = value
            end
        end
    end
    return val
end

function M.updateBrightness()
    local cursor = uci.cursor()
    local result = cursor:load("ledfw")
    if not result then
        return
    end
    brightness = {}
    cursor:foreach("ledfw", "brightness", function(t)
        local name = t["name"]
        if not name then
            return
        end
        for i = 1,#colors do
            local color = colors[i]
            local b = t[color]
            if b then
                if not brightness[name] then
                    brightness[name] = {}
                end
                brightness[name][color] = tonumber(b)
            end
        end
    end)
    cursor:close()
end

function M.updateControlPaths()
    local cursor = uci.cursor()
    local result = cursor:load("ledfw")
    if not result then
        return
    end
    ledPaths = {}
    ledAliases = {}
    cursor:foreach("ledfw", "control", function(t)
        local name = t["name"]
        if not name then
            return
        end
        ledPaths[name]=t["path"]
        for i = 1,#colors do
            local color = colors[i]
            local b = t[color]
            if b then
                ledAliases[name..':'..color] = b
            end
        end
    end)
    cursor:close()
end

local function writeTrigger(led_name,value)
    if value then
       local ledname = string.match(led_name, "(.+)[:.]")
       led_name= (ledPaths[ledname] or ledPath) .. (ledAliases[led_name] or led_name)
       syslog(posix.LOG_DEBUG,'writing to ' .. led_name .. ', trigger: ' .. value)
       local f = io.open(led_name .. "/trigger", 'w+')
       if f then
           f:write('none\n')
           f:flush()
           f:write(value .. '\n')
           f:close()
           return true
       else
           syslog(posix.LOG_ERR,'Could not open ' .. led_name .. '/trigger')
       end
    end
    return false
end

local function getParam(value)
    local val=value
    if type(value) == 'function' then val=value() end
    if type(val) == "boolean" then val=val and 1 or 0 end
	return val
end

local function writeParam(led_name,param,value)
    if value then
       local ledname = string.match(led_name, "(.+)[:.]")
       led_name= (ledPaths[ledname] or ledPath) .. (ledAliases[led_name] or led_name)
       syslog(posix.LOG_DEBUG,'setting ' .. param .. ' to ' .. value)
       local f = io.open(led_name .. "/" .. param, 'w+')
       if f then
           f:write(value)
           f:close()
           return true
       else
           syslog(posix.LOG_ERR,'Could not open ' .. led_name .. '/' .. param)
       end
    else
       syslog(posix.LOG_WARNING,'Not setting ' .. led_name .. '/' .. param .. ' (nil value)')
    end
    return false
end

function M.doLedActions(state_or_pattern,actions)
    for i=1,# actions do
        local action = actions[i]
        local action_name = action.name
        if type(action.name)=="function" then
           action_name=action.name()
        end
        if (action_name) then
            syslog(posix.LOG_DEBUG,'applying '.. state_or_pattern .. ' transition action on ' .. action_name)
        end
        -- minimum sanity check, have a name and action
        if (action_name ~= nil) and ((action.trigger ~= nil) or (action.fctn ~= nil)) then
            -- set the action to the value specified in config
            if action_name == "runFunc" then
                --syslog(posix.LOG_DEBUG,'Executing function' )
                if (action.fctn ~=nil and type(action.fctn)=="function") then
                    action.fctn(action.params)
                end
            else
                if writeTrigger(action_name, action.trigger) then
                    -- if there are additional parameters, let's apply them.
                    -- we have key,value pairs. Key is the name of the file name
                    -- value is the content to write
                    -- this needs to happen once we've set the action since that
                    -- changes the content of the sys filesystem
                    if(action.params ~= nil) then
                        -- Make sure 'brightness' is the first parameter written (important in case of a 'netdev' LED; could misbehave otherwise)
                        local val=getParam(action.params.brightness)
                        --syslog(posix.LOG_DEBUG,'brightness getParam for ' .. action_name .. ' is ' .. val)
                        if val ~= 0 and val ~= '0' then
                           val = getBrightness(action_name, val)
                        end
                        local saved_brightness=val
                        --syslog(posix.LOG_DEBUG,'brightness getParam after translation for ' .. action_name .. ' is ' .. val)
                        writeParam(action_name, "brightness", val)
                        -- Make sure 'timer_id' is written before 'bundle_brightness', otherwise  'bundle_brightness' will be reset to 255
                        val=getParam(action.params.timer_id)
                        if (val) then writeParam(action_name, "timer_id", val) end
                        for i,v in pairs(action.params) do
                            if (i ~= "brightness" and i~= "timer_id" ) then
                               if (i == "bundle_brightness") then val=saved_brightness else val=getParam(v) end
                               writeParam(action_name,i,val)
                            end
                        end
                    end
                end
            end
        end
    end
end

M.updateBrightness()
M.updateControlPaths()

return M
