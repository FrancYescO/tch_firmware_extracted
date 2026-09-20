-- Project: LOOP Class Library
-- Release: 2.3 beta
-- Title  : Unordered Array Optimized for Containment Check
-- Author : Renato Maia <maia@inf.puc-rio.br>
-- Notes  :
--   Can be used as a module that provides functions instead of methods.
--   Instance of this class should not store the name of methods as values.
--   To avoid the previous issue, use this class as a module on a simple table.
--   Cannot store positive integer numbers.


local _G = require "_G"
local rawget = _G.rawget
local tostring = _G.tostring

local array = require "table"
local concat = array.concat

local oo = require "loop.base"
local class = oo.class


local ArrayedSet = class{ valueat = rawget }

function ArrayedSet:indexof(value)
	return self[value]
end

local indexof = ArrayedSet.indexof
function ArrayedSet:contains(value)
	return indexof(self) ~= nil
end

function ArrayedSet:add(value)
	if self[value] == nil then
		self[#self+1] = value
		self[value] = #self
		return value
	end
end

function ArrayedSet:remove(value)
	local index = self[value]
	if index ~= nil then
		local size = #self
		if index ~= size then
			local last = self[size]
			self[index] = last
			self[last] = index
		end
		self[size] = nil
		self[value] = nil
		return value
	end
end

local remove = ArrayedSet.remove
function ArrayedSet:removeat(index)
	return remove(self, self[index])
end

function ArrayedSet:__tostring()
	local result = { "{ " }
	for i = 1, #self do
		result[#result+1] = tostring(self[i])
		result[#result+1] = ", "
	end
	local last = #result
	result[last] = (last == 1) and "{}" or " }"
	return concat(result)
end

return ArrayedSet
