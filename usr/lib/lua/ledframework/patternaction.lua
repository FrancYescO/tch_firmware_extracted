local io = require("io")
local uci = require('uci')
local posix = require("tch.posix")
local openlog = posix.openlog
local syslog = posix.syslog
local print, type, pairs = print, type, pairs
local Pattern = {}
Pattern.__index = Pattern

local lcur=uci.cursor()
local ledcfg='ledfw'
lcur:load(ledcfg)
local syslog_trace, err = lcur:get(ledcfg,'syslog','trace')
lcur:close()

syslog_trace = syslog_trace ~= '0'

if not syslog_trace then
    syslog=function() end
end
openlog("ledfw", posix.LOG_PID, posix.LOG_DAEMON)

--- isActive
-- check whether current pattern state is active or not
-- @return true or false when the state is active or not
function Pattern:isActive()
    if self.state == nil or self.state == self.inactivestate then
        syslog(posix.LOG_DEBUG,'LED pattern isActive : false, self.state \''..(self.state or 'nil')..'\'')
        return false
    else
        syslog(posix.LOG_DEBUG,'LED pattern isActive : true, self.state \''..(self.state or 'nil')..'\'')
        return true
    end
end

--- setInactive
-- force current pattern state to inactive (when a new pattern is activated when another one was still active,
-- to avoid that more then 1 patterns are active simultaneously
-- @return false when the state is not active
function Pattern:setInactive()

    if self.state == nil or self.state == self.inactivestate then
        syslog(posix.LOG_DEBUG,'LED pattern set to inactive failed (already inactive), self.state \''..(self.state or 'nil')..'\'')
        return false
    else
        self.state = self.inactivestate
        syslog(posix.LOG_DEBUG,'LED pattern set to inactive, self.state \''..(self.state or 'nil')..'\'')
        return true
    end
end

--- activate
-- activate pattern triggered by event
-- @return true or false whether should be activated or not
function Pattern:activate(newstate)
    local currentState = self.state

    if newstate == nil or currentState == nil then
        syslog(posix.LOG_DEBUG,'LED pattern not activated with newstate \''..(newstate or 'nil')..'\', currentState \''..(currentState or 'nil')..'\'')
       return false
    end
    if self.inactivestate == newstate or self.transitionMap[newstate] == nil then
        syslog(posix.LOG_DEBUG,'LED pattern not activated with newstate \''..(newstate or 'nil')..'\', self.inactivestate \''..(self.inactivestate or 'nil')..'\'')
       return false
    end
    if currentState == newstate then
        syslog(posix.LOG_DEBUG,'LED pattern was already active')
    else
        self.state = newstate
    end
    syslog(posix.LOG_DEBUG,'LED pattern activated with newstate \''..(newstate or 'nil')..'\'')
    return true
end

--- deactivate
-- deactivate pattern triggered by event
-- @return true or false whether should be deactivated or not
function Pattern:deactivate(newstate)
    local currentState = self.state
    if newstate == nil or newstate ~= self.inactivestate then
        syslog(posix.LOG_DEBUG,'LED pattern not deactivated with newstate \''..(newstate or 'nil')..'\', self.inactivestate \''..(self.inactivestate or 'nil')..'\'')
        return false
    end
    if currentState == nil or currentState == newstate then
        syslog(posix.LOG_DEBUG,'LED pattern not deactivated with newstate \''..(newstate or 'nil')..'\', currentState \''..(currentState or 'nil')..'\'')
        return false
    end

    self.state = newstate
    syslog(posix.LOG_DEBUG,'LED pattern deactivated with newstate \''..(newstate or 'nil')..'\'')
    return true
end

--- getLeds
-- get related LED names of this pattern
-- @return the led name table
function Pattern:getLeds()
    return self.leds
end

--- addLed
--  add related LED name in the list of leds
--  @return true
function Pattern:addLed(ledname)
    if self.leds ~= nil and self.leds[ledname] == nil then
        self.leds[ledname] = true
    end
    return true
end

--- applyAction
-- @param action the action name
-- @return true or nil, errorcode, errormsg
function Pattern:applyAction(newstate)
    local actions = self.actionMap[newstate]
    if actions == nil then
        syslog(posix.LOG_WARNING,'no pattern action defined for ' .. newstate)
        -- no action defined for this state, could be an intermediate state
        return true
    end
    -- let's apply the actions that go with this state (there can be multiple actions)
    for i=1,# actions do
        local action = actions[i]
        if type(action.name)=="function" then
           action.name=action.name()
        end
        syslog(posix.LOG_DEBUG,'applying pattern action on ' .. action.name)
        -- minimum sanity check, have a name and action
        if (action.name ~= nil) and ((action.trigger ~= nil) or (action.fctn ~= nil)) then
            -- set the action to the value specified in config
            if action.name == "runFunc" then
                --syslog(posix.LOG_DEBUG,'Executing function' )
                if (action.fctn ~=nil and type(action.fctn)=="function") then
                    action.fctn(action.params)
                end
            else
                syslog(posix.LOG_DEBUG,'writing to ' .. self.basePath .. action.name .. ', trigger: ' .. action.trigger)
                local f = io.open(self.basePath .. action.name .. "/trigger", 'w+')
                if f then
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
                            else
                                val = v
                            end
                            if val == nil then
                                val = ''
                            end
                            syslog(posix.LOG_DEBUG,'setting ' .. i .. ' to ' .. val)
                            f = io.open(self.basePath .. action.name .. "/" .. i, 'w+')
                            if f then
                                f:write(val .. '\n')
                                f:close()
                            else
                                syslog(posix.LOG_ERROR,'Could not open ' .. self.basePath .. action.name .. '/' .. i)
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

--- restoreCurrentState
function Pattern:restoreCurrentState()
    if self.state == nil then
        return
    end
    self:applyAction(self.state)
    return
end

local M = {}

--- init module
-- @param actionMap the map of actions for a state machine. for each state associate an array of actions
-- @param basePath the system path to access the leds. default to /sys/class/leds but can be changed for testing
-- @return action "object"
function M.init(state, transitionMap, actionMap, basePath)
    local self = {}
    self.inactivestate = state
    self.state = state
    self.transitionMap = transitionMap
    self.leds = {}
    self.actionMap = actionMap
    self.basePath = basePath or "/sys/class/leds/"

    setmetatable(self, Pattern)

    return self
end

return M
