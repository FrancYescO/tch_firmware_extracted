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
	local ret = self.scripthandle.entry(runtime, ...)
	collectgarbage()
	return ret
end

function ScriptLoader:poll( requester, runtime, event, ... )
	runtime.log:notice("("  .. requester .. ") runs " .. self.scriptname .. ".check(" .. event.event .. ", " .. M.parameters( ... ) .. ")" )
	local ret = self.scripthandle.check(runtime, event, ...)
	collectgarbage()
	return ret
end

function ScriptLoader:exit( requester, runtime, ... )
	runtime.log:notice("("  .. requester .. ") runs " .. self.scriptname .. ".exit(" .. M.parameters( ... ) .. ")" )
	local ret = self.scripthandle.exit(runtime, ...)
	collectgarbage()
	return ret
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
