---------------------------------
--! @file
--! @brief The State class which contains the entry, exit and main methods of the state scripts
---------------------------------

local load = require('mobiled.scriptloader').load

local State = {}
State.__index = State

function State:entry(sm)
	local ret, errMsg = true
	if self.entrys then
		ret, errMsg = self.entrys:entry(self.name, self.runtime, sm.dev_idx, sm.previousState)
	end
	sm:settimeout(500)
	return ret, errMsg
end

function State:sense(sm, event)
	return self.mains:poll(self.name, self.runtime, event, sm.dev_idx, sm.previousState)
end

function State:exit(sm, transition)
	local ret, errMsg = true
	if self.exits then
		ret, errMsg = self.exits:exit(self.name, self.runtime, transition, sm.dev_idx)
	end
	sm:stoptimeout()
	return ret, errMsg
end

function State:update(sm, event)
	local nextState
	if self.events[event.event] then
		if event.event == 'timeout' then
			event.timeout = self.timeout
			sm:stoptimeout()
		end
		nextState = self:sense(sm, event)
		if nextState ~= self.name then
			self:exit(sm, nextState)
		elseif event.event == 'timeout' and self.timeout then
			sm:settimeout(self.timeout * 1000)
		end
	end
	return nextState
end

local M = {}

--- init
-- Constructor of the State Object
-- @param name = name of sensing state
-- @param values = configuration values of this sensing state
-- @return object
function M.init(name, values, runtime)
	local self = {
		name = name,
		runtime = runtime,
		timeout = values.timeout
	}

	if values.entryexits then
		self.exits = load(values.entryexits, runtime)
		self.entrys = self.exits
	end

	if values.mains then
		self.mains, self.events = load(values.mains, runtime)
	end

	setmetatable(self, State)
	return self
end

return M
