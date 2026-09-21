local StateMachine = {}
StateMachine.__index = StateMachine

--- update
-- update to state triggered by event
-- @param transition id/name of the transition being applied to the state machine
-- @return true or false whether there was a transition or not
function StateMachine:update(transition)
    local currentTransition = self.transitionMap[self.currentState]
    if currentTransition == nil then
        -- that means we're in a state that cannot change state, weird but possible...
       return false
    end

    local nextState = currentTransition[transition]
	if type(nextState)=="function" then
	   nextState=nextState()
	end
    if nextState == nil then
        -- ok, no transition from this state on this event
       return false
    end
    -- the next state
    self.currentState = nextState
    return true
end

--- getState
-- returns the current state of the state machine
-- @return the current state
function StateMachine:getState()
    -- return the current state
    return self.currentState
end

--- getPatterns
-- returns the pattern of the led get involved
-- @rturn the patterns table
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
    self.originalState = initialState
    self.patterns = patterns
    setmetatable(self, StateMachine)

    return self
end

return M