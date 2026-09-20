---------------------------------
--! @file
--! @brief The ScriptLoader class which reads and preloads the state scripts
---------------------------------

local M = {}
local ScriptLoader = {}
local prefix = '/etc/mobiled/'

ScriptLoader.__index = ScriptLoader

local function set (list)
	local s = { timeout = true } -- timeout events by default
	if list then
		for _, l in ipairs(list) do s[l] = true end
	end
	return s
end

function ScriptLoader:name()
	return self.scriptname
end

function ScriptLoader:entry( requester, runtime, ... )
	runtime.log:notice("("  .. requester .. ") runs " .. self.scriptname .. ".entry(" .. M.parameters( ... ) .. ")" )
	return self.scripthandle.entry(runtime, ...)
end

function ScriptLoader:poll( requester, runtime, event, ... )
	runtime.log:notice("("  .. requester .. ") runs " .. self.scriptname .. ".check(" .. event.event .. ", " .. M.parameters( ... ) .. ")" )
	return self.scripthandle.check(runtime, event, ...)
end

function ScriptLoader:exit( requester, runtime, ... )
	runtime.log:notice("("  .. requester .. ") runs " .. self.scriptname .. ".exit(" .. M.parameters( ... ) .. ")" )
	return self.scripthandle.exit(runtime, ...)
end

function M.parameters(...)
	if ... then
		return table.concat({...}, ", ")
	end
end

function M.load(script, runtime)
	local self = {}
	local f = loadfile(prefix .. script .. ".lua")
	if not f then
		runtime.log:error("Error in loading script (" .. prefix .. script .. ".lua)")
		assert(false)
	end

	self.scriptname = script
	self.scripthandle = f()
	setmetatable(self, ScriptLoader)
	return self, set(self.scripthandle.SenseEventSet)
end

return M
