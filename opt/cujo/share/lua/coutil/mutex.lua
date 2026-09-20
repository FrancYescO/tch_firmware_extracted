local _G = require "_G"
local error = _G.error

local coroutine = require "coroutine"
local running = coroutine.running

local coevent = require "coutil.event"
local await = coevent.await
local emitone = coevent.emitone

local insideof = setmetatable({}, { __mode = "k" })

local module = {
	version = "1.0 alpha",
}

function module.islocked(mutex)
	return insideof[mutex] ~= nil
end

function module.ownlock(mutex)
	return insideof[mutex] == running()
end

function module.lock(mutex)
	local thread = running()
	while true do
		local inside = insideof[mutex]
		if inside == nil then
			break
		elseif inside == thread then
			error("nested lock", 2)
		end
		await(mutex)
	end
	insideof[mutex] = thread
end

function module.unlock(mutex)
	local thread = running()
	local inside = insideof[mutex]
	if inside ~= thread then
		error("lock not owned", 2)
	end
	insideof[mutex] = nil
	return emitone(mutex)
end

return module
