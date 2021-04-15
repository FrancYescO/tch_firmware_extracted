local vararg = require "vararg"
local packargs = vararg.pack

local coevent = require "coutil.event"
local await = coevent.await
local awaitall = coevent.awaitall
local awaitany = coevent.awaitany
local emitall = coevent.emitall

local function onlypending(promise, ...)
	if promise ~= nil then
		if not promise("probe") then
			return promise, onlypending(...)
		end
		return onlypending(...)
	end
end

local function pickready(promise, ...)
	if promise ~= nil then
		if promise("probe") then
			return promise
		end
		return pickready(...)
	end
end

local module = {
	version = "1.0 alpha",
	onlypending = onlypending,
	pickready = pickready,
}

function module.create()
	local results
	local function promise(probe)
		if probe then
			return results ~= nil
		elseif results == nil then
			return await(promise)
		end
		return results()
	end
	local function fulfill(...)
		local notify = (results == nil)
		results = packargs(...)
		if notify then
			emitall(promise, ...)
			return true
		end
		return false
	end
	return promise, fulfill
end

function module.awaitall(...)
	awaitall(onlypending(...))
end

function module.awaitany(...)
	local ready = pickready(...)
	if ready == nil then
		ready = awaitany(...)
	end
	return ready
end

return module
