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
		local previousState = self.previousState
		local oldStateData = self.stateData
		self.previousState = self.currentState
		self.currentState = newState
		self.stateData = {}
		local ret, errMsg = self.states[newState]:entry(self)
		-- Revert to old state
		if not ret then
			if errMsg then self.runtime.log:error(errMsg) end
			self.currentState = self.previousState
			self.previousState = previousState
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
	local self = {
		dev_idx = dev_idx,
		runtime = runtime,
		currentState = initState,
		cb = callback,
		states = {},
		stateData = {}
	}

	for name, config in pairs(stateConfig) do
		if not config.mains then
			self.runtime.log:error('Missing mains parameter for state "%s"', name)
		end
		self.states[name] = State.init(name, config, runtime)
	end

	self.timeout = function()
		self.cb('mobiled', { event = 'timeout', dev_idx = self.dev_idx })
	end
	self.timer = runtime.uloop.timer(self.timeout)

	setmetatable(self, StateMachine)
	return self
end

return M
