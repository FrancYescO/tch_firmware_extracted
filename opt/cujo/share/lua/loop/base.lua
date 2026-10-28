-- Project: LOOP - Lua Object-Oriented Programming
-- Release: 3.0 beta
-- Title  : Base Class Model
-- Author : Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local getmetatable = _G.getmetatable
local pairs = _G.pairs
local rawget = _G.rawget
local setmetatable = _G.setmetatable

local function rawnew(class, object)
	if object == nil then object = {} end
	return setmetatable(object, class)
end

local function new(class, ...)
	local new = class.__new
	if new ~= nil then
		return new(class, ...)
	end
	return rawnew(class, ...)
end

local function initclass(class)
	if class == nil then class = {} end
	if class.__index == nil then class.__index = class end
	return class
end

local oo = {
	initclass = initclass,
	getclass = getmetatable,
	getmember = rawget,
	members = pairs,
	new = new,
	rawnew = rawnew,
}

local ClassMT = setmetatable({ __call = new }, { __index = oo })

function oo.class(class)
	return setmetatable(initclass(class), ClassMT)
end

function oo.isclass(class)
	return getmetatable(class) == ClassMT
end

function oo.isinstanceof(object, class)
	return getmetatable(object) == class
end

return oo
