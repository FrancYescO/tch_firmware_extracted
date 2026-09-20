-- Project: LOOP Class Library
-- Release: 2.3 beta
-- Title  : Array Optimized for Insertion/Removal that Doesn't Garantee Order
-- Author : Renato Maia <maia@inf.puc-rio.br>
-- Notes  :
--   Can be used as a module that provides funcitons instead of methods.
--   Removal is replacing the element by the last one, which is then removed.


local _G = require "_G"
local tostring = _G.tostring

local array = require "table"
local concat = array.concat

local oo = require "loop.base"
local class = oo.class

local UnorderedArray = class()

function UnorderedArray:add(value)
	self[#self + 1] = value
end

function UnorderedArray:remove(index)
	local size = #self
	if index == size then
		self[size] = nil
	elseif (index > 0) and (index < size) then
		self[index], self[size] = self[size], nil
	end
end

function UnorderedArray:__tostring()
	local result = { "{ " }
	for i = 1, #self do
		result[#result+1] = tostring(self[i])
		result[#result+1] = ", "
	end
	local last = #result
	result[last] = (last == 1) and "{}" or " }"
	return concat(result)
end

return UnorderedArray
