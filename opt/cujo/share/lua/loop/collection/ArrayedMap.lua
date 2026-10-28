-- Project: LOOP Class Library
-- Release: 2.3 beta
-- Title  : Map of Objects that Keeps an Array of Key Values
-- Author : Renato Maia <maia@inf.puc-rio.br>
-- Notes  :
--   Can be used as a module that provides functions instead of methods.
--   Instance of this class should not store the name of methods as keys.
--   To avoid the previous issue, use this class as a module on a simple table.
--   Cannot store positive integer numbers.


local _G = require "_G"
local ipairs = _G.ipairs
local rawget = _G.rawget
local tostring = _G.tostring

local array = require "table"
local concat = array.concat
local insert = array.insert

local oo = require "loop.base"
local class = oo.class


local ArrayedMap = class{
	keys = ipairs,
	keyat = rawget,
}

function ArrayedMap:value(key, value)
	if value == nil
		then return self[key]
		else self[key] = value
	end
end

function ArrayedMap:add(key, value)
	self[#self + 1] = key
	self[key] = value
end

function ArrayedMap:addat(index, key, value)
	insert(self, index, key)
	self[key] = value
end

function ArrayedMap:removeat(index)
	local key = self[index]
	if key ~= nil then
		local size = #self
		if index ~= size then
			self[index] = self[size]
		end
		self[size] = nil
		self[key] = nil
		return key
	end
end

function ArrayedMap:valueat(index, value)
	if value == nil
		then return self[ self[index] ]
		else self[ self[index] ] = value
	end
end

function ArrayedMap:__tostring()
	local result = { "{ " }
	for i = 1, #self do
		local key = self[i]
		result[#result+1] = "["
		result[#result+1] = tostring(key)
		result[#result+1] = "]="
		result[#result+1] = tostring(self[key])
		result[#result+1] = ", "
	end
	local last = #result
	result[last] = (last == 1) and "{}" or " }"
	return concat(result)
end

return ArrayedMap
