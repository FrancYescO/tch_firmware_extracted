local io = require("io")
local uci = require('uci')
local posix = require("tch.posix")
local openlog = posix.openlog
local syslog = posix.syslog
local print, type, pairs = print, type, pairs
local Action = {}
Action.__index = Action

local lcur=uci.cursor()
local ledcfg='ledfw'
lcur:load(ledcfg)
local syslog_trace, err = lcur:get(ledcfg,'syslog','trace')
lcur:close()

if syslog_trace == nil then
    syslog_trace = true
elseif syslog_trace == '0' then
    syslog_trace = false
else
    syslog_trace = true
end

if not syslog_trace then
    syslog=function() end
end
openlog("ledfw", posix.LOG_PID, posix.LOG_DAEMON)

--- applyAction
-- @param action the action name
-- @return true or nil, errorcode, errormsg
function Action:applyAction(action)
    local actions = self.actionMap[action]
    if actions == nil then
        syslog(posix.LOG_WARNING,'no action defined for ' .. action)
        -- no action defined for this state, could be an intermediate state
        return true
    end
    -- let's apply the actions that go with this state (there can be multiple actions)
    for i=1,# actions do
        local action = actions[i]
        if type(action.name)=="function" then
           action.name=action.name()
        end
		if (action.name) then 
           syslog(posix.LOG_DEBUG,'applying action on ' .. action.name)
		end
        -- minimum sanity check, have a name and action
        if (action.name ~= nil) and ((action.trigger ~= nil) or (action.fctn ~= nil)) then
            -- set the action to the value specified in config
            if action.name == "runFunc" then
                --syslog(posix.LOG_DEBUG,'Executing function' )
                if (action.fctn ~=nil and type(action.fctn)=="function") then
                    action.fctn(action.params)
                end
            else
                syslog(posix.LOG_DEBUG,'writing to ' .. self.basePath .. action.name .. ' with action ' .. action.trigger)
                local f = io.open(self.basePath .. action.name .. "/trigger", 'w+')
                if f then
                    f:write('none\n')
                    f:flush()
                    f:write(action.trigger .. '\n')
                    f:close()

                    -- if there are additional parameters, let's apply them.
                    -- we have key,value pairs. Key is the name of the file name
                    -- value is the content to write
                    -- this needs to happen once we've set the action since that
                    -- changes the content of the sys filesystem
                    if(action.params ~= nil) then
                        for i,v in pairs(action.params) do
                            local val
                            if type(v) == "function" then
                                val = v()
                                if type(val)=="boolean" then val=val and 255 or 0 end
                            else
                                val = v
                            end
                            if val  then
                               syslog(posix.LOG_DEBUG,'setting ' .. i .. ' to ' .. val)
                               f = io.open(self.basePath .. action.name .. "/" .. i, 'w+')
                               if f then
                                   f:write(val)
                                   f:close()
                               else
                                   syslog(posix.LOG_ERR,'Could not open ' .. self.basePath .. action.name .. '/' .. i)
                               end
                            end
                        end
                    end
                else
                    syslog(posix.LOG_WARNING,'Could not open ' .. self.basePath .. action.name .. '/trigger')
                end
            end
        end
    end

    return true
end

local M = {}

--- init module
-- @param actionMap the map of actions for a state machine. for each state associate an array of actions
-- @param basePath the system path to access the leds. default to /sys/class/leds but can be changed for testing
-- @return action "object"
function M.init(actionMap, basePath)
    local self = {}
    self.actionMap = actionMap
    self.basePath = basePath or "/sys/class/leds/"

    setmetatable(self, Action)

    return self
end

return M
