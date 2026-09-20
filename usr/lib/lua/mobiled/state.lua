---------------------------------
--! @file
--! @brief The State class which contains the entry, exit and main methods of the state scripts
---------------------------------

local loader = require('mobiled.scriptloader')
local load = loader.load

local State = {}
State.__index = State

function State:entry(sm, dev_idx)
	local errMsg
	local ret = true

	if self.entrys then
		ret, errMsg = self.entrys:entry(self.name, self.runtime, dev_idx)
	end
	sm:settimeout(500)
	return ret, errMsg
end

function State:sense(sm, event, dev_idx, previous_state)
	--lets call the check script
	return self.mains:poll(self.name, self.runtime, event, dev_idx, previous_state)
end

function State:exit(sm, transition, dev_idx)
	if self.exits then
		self.exits:exit(self.name, self.runtime, transition, dev_idx)
	end
	-- lets cancel the timeout timer, we are done
	sm:stoptimeout()
end

function State:update(sm, event, dev_idx, previous_state)
	local nextState
	local timeout = self.timeout * 1000
	-- event can be handled in this state
	if self.events[event.event] then
		if event.event == 'timeout' then
			event.timeout = self.timeout
		end
		nextState = self:sense(self.runtime, event, dev_idx, previous_state)
		-- leaving current state?
		if nextState ~= self.name then
			self:exit(sm, nextState, dev_idx)
		else
			-- we keep in the same state
			-- in case of a timeout event, lets rearm the timer
			if event.event == 'timeout' then
				sm:settimeout(timeout)
			end
		end
	else
		-- event can't be handled in this state
		return nil
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

