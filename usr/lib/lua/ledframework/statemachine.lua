local uci = require('uci')
local posix = require("tch.posix")
local openlog = posix.openlog
local syslog = posix.syslog

local lcur=uci.cursor()
local ledcfg='ledfw'
lcur:load(ledcfg)
local syslog_trace, err = lcur:get(ledcfg,'syslog','trace')
lcur:close()

syslog_trace = syslog_trace == '1'
if not syslog_trace then
    syslog=function() end
end
openlog("ledfw", posix.LOG_PID, posix.LOG_DAEMON)

local StateMachine = {}
StateMachine.__index = StateMachine

local function stateAndActionFor(nextstate)
    local next_state, next_action

    next_state=nextstate.new_state
    next_action=nextstate.action
    if not next_state then
       next_state=nextstate[1]
    end
    if not next_action then
       next_action=nextstate[2]
    end
    return next_state, next_action
end

local function handleSimpleState(nextstate)
    local next_state, next_action

    next_state=nextstate
    next_action=next_state
    return next_state, next_action
end

local function handleFunctionState(nextstate)
    local next_state, next_action

    next_state=nextstate()
    next_action=next_state
    return next_state, next_action
end

local function handleTableState(nextstate)
    local next_state, next_action

    -- First table entry is new state, second is action (and both can be tables again:a function and its optional parameters)
    local state, action = stateAndActionFor(nextstate)
    local t_state = type(state)
    local t_action = type(action)
    if t_state == "function" and t_action == "string" then
       -- This case is needed for backwards compatibility (existing proximus led config : first entry in table is function, second is parameter to the function;)
       next_state=state(action)
       next_action=next_state
       return next_state, next_action
    end
    if t_state == "string" or t_state == "nil" then
       next_state=state
    elseif t_state == "table" then
       -- If state table first entry is a function, then the second one must be its parameters)
       if type(state[1]) == "function" then
          next_state=state[1](state[2])
       else
          next_state=state[1]
       end
    end
    if t_action == "string" or t_action == "nil" then
       next_action=action
    elseif t_action == "table" then
       -- If action table first entry is a function, then the second one must be its parameters)
       if type(action[1]) == "function" then
          next_action=action[1](action[2])
       else
          next_action=action[1]
       end
    end
    return next_state, next_action
end


local function getNextStateAndAction(ns)
    local t_ns = type(ns)

    if t_ns == "string" or t_ns == "nil" then
       return handleSimpleState(ns)
    elseif t_ns == "function" then
       return handleFunctionState(ns)
    elseif t_ns == "table" then
       return handleTableState(ns)
    end
end

--- update
-- update to state triggered by event
-- @param transition id/name of the transition (event) being applied to the state machine
-- @return true or false whether there was a transition or not
function StateMachine:update(transition)
    local currentTransition = self.transitionMap[self.currentState]
    if currentTransition == nil then
        -- that means we're in a state that cannot change state, weird but possible...
       return false
    end

    local nextState, nextAction =  getNextStateAndAction(currentTransition[transition])
    if not self.transitionMap[nextState] then
       -- non-existing next state: avoid transition
       nextState=nil
    end
    if not nextState and not nextAction then
        -- ok, no transition from this state on this event
       return false
    end
    -- the next state
    if nextState then
       syslog(posix.LOG_DEBUG,'LED State update from \''..(self.currentState or 'nil')..'\' to \''..(nextState or 'nil')..'\'')
       self.currentState = nextState
    end
    syslog(posix.LOG_DEBUG,'LED Action update from \''..(self.currentAction or 'nil')..'\' to \''..(nextAction or 'nil')..'\'')
    if nextAction then self.lastActiveAction = nextAction end
    self.currentAction = nextAction
    return true
end

--- getState
-- returns the current state of the state machine
-- @return the current state
function StateMachine:getState()
    -- return the current state
    return self.currentState
end

--- getAction
-- returns the current action of the state machine
-- @return the current action
function StateMachine:getAction()
    -- return the current action
    return self.currentAction
end

--- getActiveAction
-- returns the last non-nil action of the state machine
-- @return the active action
function StateMachine:getActiveAction()
    -- return the last active (non-nil) action
    return self.lastActiveAction
end

--- getPatterns
-- returns the array of depending patterns for the led (StateMachine) in the state triggered by 'transition'
-- @return the patterns table
function StateMachine:getPatterns(transition)
    if self.patterns == nil or transition == nil then
        return nil
    end
    return self.patterns[transition]
end

--- suspend
-- power leds triggered by event
-- @return true or false whether there was a transition or not
function StateMachine:suspend()
    self.originalState = self.currentState;
end

--- resume
-- power leds triggered by event
-- @return true or false whether there was a transition or not
function StateMachine:resume()
    self.currentState = self.originalState;
end

local M = {}

function M.init(transitionMap, initialState, patterns)
    local self = {}
    self.transitionMap = transitionMap
    self.currentState = initialState
    self.currentAction = initialState
    self.lastActiveAction = initialState
    self.originalState = initialState
    self.patterns = patterns
    setmetatable(self, StateMachine)

    return self
end

return M
