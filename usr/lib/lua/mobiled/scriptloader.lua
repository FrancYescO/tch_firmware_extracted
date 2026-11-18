---------------------------------
--! @file
--! @brief The ScriptLoader class which reads and preloads the state scripts
---------------------------------

local tostring, assert, pcall, ipairs, collectgarbage = tostring, assert, pcall, ipairs, collectgarbage

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
	local status, ret = pcall(self.scripthandle.entry, runtime, ...)
	if not status or not ret then
		runtime.log:error(self.scriptname .. ".entry(" .. M.parameters( ... ) .. ") throws error: " .. tostring(ret) )
		return nil, "Error in script " .. self.scriptname
	end
	collectgarbage()
	return ret
end

function ScriptLoader:poll( requester, runtime, event, ... )
	runtime.log:notice("("  .. requester .. ") runs " .. self.scriptname .. ".check(" .. event.event .. ", " .. M.parameters( ... ) .. ")" )
	local status, ret = pcall(self.scripthandle.check, runtime, event, ...)
	if not status then
		runtime.log:error(self.scriptname .. ".check(" .. event.event .. ", " .. M.parameters( ... ) .. ") throws error: " .. tostring(ret) )
		return nil, "Error in script " .. self.scriptname
	end
	collectgarbage()
	return ret
end

function ScriptLoader:exit( requester, runtime, ... )
	runtime.log:notice("("  .. requester .. ") runs " .. self.scriptname .. ".exit(" .. M.parameters( ... ) .. ")" )
	local status,ret = pcall(self.scripthandle.exit, runtime, ...)
	if not status or not ret then
		runtime.log:error(self.scriptname .. ".exit(" .. M.parameters( ... ) .. ") throws error: " .. tostring(ret) )
		return nil, "Error in script " .. self.scriptname
	end
	collectgarbage()
	return ret
end

function M.parameters( ... )
	if ( arg.n )  then
		return table.concat(arg, ", ")
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
