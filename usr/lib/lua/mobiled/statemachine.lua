---------------------------------
--! @file
--! @brief The StateMachine class which cycles trough the different states
---------------------------------

local State = require('mobiled.state')

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine:handle_event(event)
	local newState = self.states[self.currentState]:update(self, event)
	if not newState or not self.states[newState] then
		return
	end
	-- Entering a new state?
	if newState ~= self.currentState then
		local previousState = self.currentState
		self.currentState = newState
		local oldStateData = self.stateData
		self.stateData = {}
		local ret, errMsg = self.states[newState]:entry(self)
		if not ret then
			if errMsg then self.runtime.log:error(errMsg) end
			self.currentState = previousState
			self.stateData = oldStateData
		end
	end
end

function StateMachine:get_state()
	return self.currentState
end

function StateMachine:get_state_data()
	return self.stateData
end

function StateMachine:start()
	return self.states[self.currentState]:entry(self, self.dev_idx)
end

function StateMachine:settimeout(t)
	self.timer:set(t)
end

function StateMachine:stoptimeout()
	if self.timer then
		self.timer:cancel()
		self.timer = self.runtime.uloop.timer(self.timeout)
	end
end

local M = {}

function M.create(stateConfig, initState, runtime, dev_idx, callback)
	local self = {}
	self.dev_idx = dev_idx
	self.runtime = runtime
	self.currentState = initState
	self.states = {}
	self.stateData = {}
	for k, v in pairs(stateConfig) do
		if v == nil or v.mains == nil then
			self.runtime.log:error('Error in start, missing config parameter for ' .. k)
		end
		self.states[k] = State.init(k, v, runtime)
	end

	self.timeout = function()
		self.cb({ event = 'timeout', dev_idx = self.dev_idx })
	end

	self.timer = runtime.uloop.timer(self.timeout)
	self.cb = callback

	setmetatable(self, StateMachine)
	return self
end

return M
