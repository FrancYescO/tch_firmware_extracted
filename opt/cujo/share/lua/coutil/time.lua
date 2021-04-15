local _G = require "_G"
local assert = _G.assert
local type = _G.type

local os = require "os"
local gettime = os.time

local event = require "coutil.event"
local awaitany = event.awaitany

local timevt = require "coutil.time.event"
local canceltimer = timevt.cancel
local setuptimer = timevt.create
local emituntil = timevt.emitall
local dynnextwake = timevt.nextwake

local function waitdone(timestamp, event, ...)
	if event ~= timestamp then
		canceltimer(timestamp)
	end
	return event, ...
end

local function waituntil(timestamp, ...)
	setuptimer(timestamp)
	return waitdone(timestamp, awaitany(timestamp, ...))
end

local module = {
	gettime = gettime,
	waituntil = waituntil,
}

function module.setclock(func)
	assert(type(func) == "function", "bad argument #1 (function expected)")
	gettime = func
	module.gettime = func
end

function module.sleep(delay, ...)
	return waituntil(gettime()+delay, ...)
end

function module.run(idle, timeout)
	while true do
		local nextwake = emituntil(gettime())
		if nextwake == nil then
			return
		end
		local now = gettime()
		if timeout ~= nil and timeout <= now then
			return nextwake
		end
		if nextwake > now then
			idle(dynnextwake)
		end
	end
end

return module
