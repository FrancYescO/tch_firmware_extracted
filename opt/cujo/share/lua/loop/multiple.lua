-- Project: LOOP - Lua Object-Oriented Programming
-- Release: 3.0 beta
-- Title  : Multiple Inheritance Class Model
-- Author : Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local ipairs = _G.ipairs
local getmetatable = _G.getmetatable
local select = _G.select
local setmetatable = _G.setmetatable

local array = require "table"
local unpack = array.unpack or _G.unpack

local table = require "loop.table"
local copy = table.copy

local proto = require "loop.proto"
local clone = proto.clone

local simple = require "loop.simple"
local initclass = simple.initclass
local issimpleclass = simple.isclass
local getsimplesuper = simple.getsuper
local getclass = simple.getclass
local new = simple.new
local simpleclass = simple.class

local function inherit(self, field)
	for _, super in ipairs(getclass(self)) do
		local value = super[field]
		if value ~= nil then return value end
	end
end

local function isingle(single, index)
	if single ~= nil and index == nil then
		return 1, single
	end
end

local function supers(class)
	local classmt = getmetatable(class)
	if classmt ~= nil then
		if classmt.__index == inherit then
			return ipairs(classmt)
		end
		return isingle, getsimplesuper(class)
	end
	return isingle
end

local function issubclassof(class, super)
	if class == super then return true end
	for _, base in supers(class) do
		if issubclassof(base, super) then
			return true
		end
	end
	return false
end

local oo = clone(simple, {
	supers = supers,
	issubclassof = issubclassof,
})

local ClassMetatableMT = { __index = oo }
function oo.class(class, ...)
	if select("#", ...) > 1 then
		local classmt = { __call = new, __index = inherit, ... }
		setmetatable(classmt, ClassMetatableMT)
		return setmetatable(initclass(class), classmt)
	end
	return simpleclass(class, ...)
end

function oo.isclass(class)
	local classmt = getmetatable(class)
	if classmt ~= nil then
		if classmt.__index == inherit then
			return true
		end
		return issimpleclass(class)
	end
	return false
end

function oo.isinstanceof(object, class)
	return issubclassof(getclass(object), class)
end

function oo.getsuper(class)
	local classmt = getmetatable(class)
	if classmt ~= nil then
		if classmt.__index == inherit then
			return unpack(classmt)
		end
		return getsimplesuper(class)
	end
end

return oo
