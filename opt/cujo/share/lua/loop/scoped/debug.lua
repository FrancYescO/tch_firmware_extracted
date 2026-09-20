-- Project: LOOP - Lua Object-Oriented Programming
-- Title  : Scoped Class Model Debugging Utilities
-- Author : Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local assert = _G.assert

local debug = require "debug"
local getupvalue = debug.getupvalue

local module = {}

function module.methodfunction(method)
	local name, value = getupvalue(method, 4)
	assert(name == "method", "Oops! Got the wrong upvalue in 'methodfunction'")
	return value
end

function module.methodclass(method)
	local name, value = getupvalue(method, 2)
	assert(name == "class", "Oops! Got the wrong upvalue in 'methodclass'")
	return value.proxy
end

return module
