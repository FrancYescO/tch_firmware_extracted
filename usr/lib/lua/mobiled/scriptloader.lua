---------------------------------
--! @file
--! @brief The ScriptLoader class which reads and preloads the state scripts
---------------------------------

local ScriptLoader = {}
ScriptLoader.__index = ScriptLoader

local function set(list)
	local s = { timeout = true } -- timeout events by default
	if list then
		for _, l in ipairs(list) do s[l] = true end
	end
	return s
end

local function parameters(...)
	if ... then
		return table.concat({...}, ", ")
	end
	return ""
end

function ScriptLoader:name()
	return self.scriptname
end

function ScriptLoader:entry(requester, runtime, ...)
	if not self.scripthandle.entry then
		return true
	end
	runtime.log:info("(%s) runs %s.entry(%s)", requester, self.scriptname, parameters(...))
	return self.scripthandle.entry(runtime, ...)
end

function ScriptLoader:poll(requester, runtime, event, ...)
	runtime.log:info("(%s) runs %s.check(%s, %s)", requester, self.scriptname, event.event, parameters(...))
	return self.scripthandle.check(runtime, event, ...)
end

function ScriptLoader:exit(requester, runtime, ...)
	if not self.scripthandle.exit then
		return true
	end
	runtime.log:info("(%s) runs %s.exit(%s)", requester, self.scriptname, parameters(...))
	return self.scripthandle.exit(runtime, ...)
end

local M = {}
local scripts_folder = '/etc/mobiled/'

function M.load(script, runtime)
	local self = {
		scriptname = script
	}
	local script_path = string.format("%s%s.lua", scripts_folder, script)
	local f, errMsg = loadfile(script_path)
	if not f then
		runtime.log:error('Error in loading script "%s" (%s)', script_path, errMsg)
		assert(false)
	end
	self.scripthandle = f()
	setmetatable(self, ScriptLoader)
	return self, set(self.scripthandle.SenseEventSet)
end

return M
