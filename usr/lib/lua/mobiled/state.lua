---------------------------------
--! @file
--! @brief The State class which contains the entry, exit and main methods of the state scripts
---------------------------------

local loader = require('mobiled.scriptloader')
local load = loader.load

local State = {}
State.__index = State

function State:entry(sm)
	local errMsg
	local ret = true
	-- States can store info in themselves for the duration of their main
	if self.entrys then
		ret, errMsg = self.entrys:entry(self.name, self.runtime, sm.dev_idx)
	end
	sm:settimeout(500)
	return ret, errMsg
end

function State:sense(sm, event)
	-- lets call the check script
	return self.mains:poll(self.name, self.runtime, event, sm.dev_idx, sm.previous_state)
end

function State:exit(sm, transition)
	local errMsg
	local ret = true
	if self.exits then
		ret, errMsg = self.exits:exit(self.name, self.runtime, transition, sm.dev_idx)
	end
	-- lets cancel the timeout timer, we are done
	sm:stoptimeout()
	return ret, errMsg
end

function State:update(sm, event)
	local nextState
	-- event can be handled in this state
	if self.events[event.event] then
		if event.event == 'timeout' then
			event.timeout = self.timeout
		end
		nextState = self:sense(sm, event)
		-- leaving current state?
		if nextState ~= self.name then
			self:exit(sm, nextState)
		else
			-- we keep in the same state
			-- in case of a timeout event, lets rearm the timer
			if event.event == 'timeout' then
				sm:settimeout(self.timeout * 1000)
			end
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
	local self = { name = name, timeout = 60}

	if values.timeout then
		self.timeout = values.timeout
	end

	if ( values.entryexits and values.entryexits ~= "" ) then
		self.exits = load(values.entryexits, runtime)
		self.entrys = self.exits
	end
	if ( values.mains and values.mains ~= "" ) then
		self.mains, self.events = load(values.mains, runtime)
	end

	self.runtime = runtime
	setmetatable(self, State)

	return self
end

return M
