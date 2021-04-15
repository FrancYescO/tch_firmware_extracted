local _G = require "_G"
local assert = _G.assert
local type = _G.type
local xpcall = _G.xpcall

local timing = require "coutil.timing"
local newthread = timing.create
local names = timing.names
local resume = timing.resume


local function onterm(handler, success, ...)
	if success then
		handler(true, ...)
	end
end

local function trapcall(f, handler, ...)
	local function onerror(...)
		handler(false, ...)
	end
	onterm(handler, xpcall(f, onerror, ...))
end

local module = {}

function module.trap(handler, name, f, ...)
	assert(type(handler) == "function", "bad argument #1 (function expected)")
	resume(newthread(trapcall, name), f, handler, ...)
end

function module.catch(handler, name, f, ...)
	assert(type(handler) == "function", "bad argument #1 (function expected)")
	resume(newthread(xpcall, name), f, handler, ...)
end

return module
