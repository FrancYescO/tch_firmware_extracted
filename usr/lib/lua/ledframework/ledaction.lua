local io = require("io")
local syslog = require("syslog")
local print, type, pairs = print, type, pairs
local Action = {}
Action.__index = Action

syslog.openlog("ledfw", syslog.options.LOG_PID, syslog.facilities.LOG_DAEMON)

--- applyAction
-- @param action the action name
-- @return true or nil, errorcode, errormsg
function Action:applyAction(action)
    local actions = self.actionMap[action]
    if actions == nil then
        syslog.warning('no action defined for ' .. action)
        -- no action defined for this state, could be an intermediate state
        return true
    end
    -- let's apply the actions that go with this state (there can be multiple actions)
    for i=1,# actions do
        local action = actions[i]
        syslog.debug('applying action on ' .. action.name)
        -- minimum sanity check, have a name and action
        if (action.name ~= nil) and (action.trigger ~= nil) then
            -- set the action to the value specified in config
            syslog.debug('writing to ' .. self.basePath .. action.name .. ' with action ' .. action.trigger)
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
                        syslog.debug('setting ' .. i .. ' to ' .. val)
                        f = io.open(self.basePath .. action.name .. "/" .. i, 'w+')
                        if f then
                            f:write(val .. '\n')
                            f:close()
                        else
                            syslog.error('Could not open ' .. self.basePath .. action.name .. '/' .. i)
                        end
                    end
                end
            else
                syslog.warning('Could not open ' .. self.basePath .. action.name .. '/trigger')
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