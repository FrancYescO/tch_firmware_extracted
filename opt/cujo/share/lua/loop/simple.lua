-- Project: LOOP - Lua Object-Oriented Programming
-- Release: 3.0 beta
-- Title  : Simple Inheritance Class Model
-- Author : Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local getmetatable = _G.getmetatable
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local rawget = _G.rawget

local table = require "loop.table"
local memoize = table.memoize

local base = require "loop.base"
local baseclass = base.class
local initclass = base.initclass
local isbaseclass = base.isclass
local getclass = base.getclass
local new = base.new

local proto = require "loop.proto"
local clone = proto.clone

local oo = clone(base)

local ClassMetatableMT = { __index = oo }
local DerivedMT = memoize(function(super)
	return setmetatable({ __index = super, __call = new }, ClassMetatableMT)
end, "v")

local function getsuper(class)
	local classmt = getmetatable(class)
	if classmt ~= nil then
		local super = classmt.__index
		if classmt == rawget(DerivedMT, super) then
			return super
		end
	end
end

local function issubclassof(class, super)
	while class ~= nil do
		if class == super then return true end
		class = getsuper(class)
	end
	return false
end

oo.getsuper = getsuper
oo.issubclassof = issubclassof

function oo.class(class, super)
	if super ~= nil then
		return setmetatable(initclass(class), DerivedMT[super])
	end
	return baseclass(class)
end

function oo.isclass(class)
	local classmt = getmetatable(class)
	if classmt ~= nil then
		if classmt == rawget(DerivedMT, classmt.__index) then
			return true
		end
		return isbaseclass(class)
	end
	return false
end

function oo.isinstanceof(object, class)
	return issubclassof(getclass(object), class)
end

return oo
