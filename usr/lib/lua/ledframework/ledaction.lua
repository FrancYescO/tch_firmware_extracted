local comm = require('ledframework.common')
local io = require("io")
local posix = require("tch.posix")
local syslog=comm.syslog
local print, type, pairs = print, type, pairs
local doLedActions = comm.doLedActions
local Action = {}
Action.__index = Action

--- applyAction
-- @param action the action name
-- @return true or nil, errorcode, errormsg
function Action:applyAction(action)
    local actions = action and self.actionMap[action]
    if actions == nil then
        syslog(posix.LOG_WARNING,'no state transition action defined for ' .. action)
        -- no action defined for this state, could be an intermediate state
        return true
    end
    -- let's apply the actions that go with this state (there can be multiple actions)
    doLedActions("state",actions)

    return true
end

local M = {}

--- init module
-- @param actionMap the map of actions for a state machine. for each state associate an array of actions
-- @return action "object"
function M.init(actionMap)
    local self = {}
    self.actionMap = actionMap

    setmetatable(self, Action)

    return self
end

return M
