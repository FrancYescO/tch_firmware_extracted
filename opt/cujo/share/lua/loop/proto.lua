-- Project: LOOP - Lua Object-Oriented Programming
-- Release: 3.0 beta
-- Title  : Dymamic Prototyping Model
-- Author : Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local getmetatable = _G.getmetatable
local rawget = _G.rawget
local setmetatable = _G.setmetatable

local table = require "loop.table"
local memoize = table.memoize

local CloneOf = memoize(function(proto) return { __index = proto } end, "v")

local oo = {}

function oo.clone(proto, clone)
	if clone == nil then clone = {} end
	return setmetatable(clone, CloneOf[proto])
end

function oo.getproto(clone)
	local meta = getmetatable(clone)
	if meta ~= nil then
		local proto = meta.__index
		if meta == rawget(CloneOf, proto) then
			return proto
		end
	end
end

function oo.iscloneof(clone, proto)
	local meta = rawget(CloneOf, proto)
	return meta ~= nil and meta == getmetatable(clone)
end

return oo
