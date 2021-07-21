-- Project: LOOP Class Library
-- Title  : 
-- Author : Renato Maia <maia@inf.puc-rio.br>

local coroutine = require "coroutine"
local wrap = coroutine.wrap
local yield = coroutine.yield

local oo = require "loop"
local getmember = oo.getmember
local rawnew = oo.rawnew
local supers = oo.supers

local function yieldsupers(history, class)
	for _, super in supers(class) do
		yieldsupers(history, super)
	end
	if history[class] == nil then
		history[class] = true
		yield(class)
	end
end

local function topdown(class)
	return wrap(yieldsupers), {}, class
end

local module = {
	topdown = topdown,
}

function module.creator(class, ...)
	local obj = rawnew(class)
	local init = obj.__init
	if init ~= nil then init(obj, ...) end
	return obj
end

function module.mutator(class, obj, ...)
	obj = rawnew(class, obj)
	for class in topdown(class) do
		local init = getmember(class, "__init")
		if init ~= nil then init(obj, ...) end
	end
	return obj
end

return module
