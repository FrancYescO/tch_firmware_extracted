--------------------------------------------------------------------------------
-- Project: LOOP - Lua Object-Oriented Programming                            --
-- Title  : Static Class Model without Support for Introspection              --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------

local _G = require "_G"
local getfenv = _G.getfenv
local setfenv = _G.setfenv
local setmetatable = _G.setmetatable
local type = _G.type

module "loop.static"

local BuilderOf = setmetatable({}, { __mode = "k" })

function class(builder)
	local function class(...)
		local object = {}
		setfenv(builder, object)
		local result = builder(...)
		if result ~= nil then
			setfenv(builder, result)
		end
		return getfenv(builder)
	end
	BuilderOf[class] = builder
	return class
end

function inherit(class, ...)
	local builder = BuilderOf[class]
	setfenv(builder, getfenv(2))
	return builder(...)
end

function become(object)
	if object ~= nil then
		setfenv(2, object)
	end
end

function self(level)
	return getfenv((level or 1) + 1)
end

function new(class, ...)
	return class(...)
end
