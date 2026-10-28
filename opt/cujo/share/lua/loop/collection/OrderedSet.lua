-- Project: LOOP Class Library
-- Release: 2.3 beta
-- Title  : Ordered Set Optimized for Insertions and Removals
-- Author : Renato Maia <maia@inf.puc-rio.br>
-- Notes  :
--   Can be used as a module that provides functions instead of methods.
--   Instance of this class should not store the name of methods as values.
--   To avoid the previous issue, use this class as a module on a simple table.
--   It cannot store itself, because this place is reserved.
--   Each element is stored as a key mapping to its successor.


local _G = require "_G"
local tostring = _G.tostring

local array = require "table"
local concat = array.concat

local oo = require "loop.base"
local class = oo.class

local CyclicSets = require "loop.collection.CyclicSets"
local addto = CyclicSets.add
local removeat = CyclicSets.removefrom


local LastTag = {"OrderedSet.LastTag"}


local OrderedSet = class{
	contains = CyclicSets.contains,
}

function OrderedSet:empty()
	return self[LastTag] == nil
end

function OrderedSet:first()
	return self[ self[LastTag] ]
end

function OrderedSet:last()
	return self[LastTag]
end

function OrderedSet:successor(item)
	local last = self[LastTag]
	if item ~= last then
		if item == nil then item = last end
		return self[item]
	end
end

local successor = OrderedSet.successor
function OrderedSet:sequence(place)
	return successor, self, place
end

function OrderedSet:insert(item, place)
	local last = self[LastTag]
	if place == nil then place = last end
	if self[place] ~= nil and addto(self, item, place) == item then
		if place == last then self[LastTag] = item end
		return item
	end
end

function OrderedSet:removefrom(place)
	local last = self[LastTag]
	if place ~= last then
		if place == nil then place = last end
		local item = removeat(self, place)
		if item ~= nil then
			if item == last then self[LastTag] = place end
			return item
		end
	end
end

function OrderedSet:pushfront(item)
	local last = self[LastTag]
	if addto(self, item, last) == item then
		if last == nil then self[LastTag] = item end
		return item
	end
end

local removefrom = OrderedSet.removefrom
function OrderedSet:popfront()
	local last = self[LastTag]
	if self[last] == last then
		self[LastTag] = nil
	end
	return removefrom(self, last)
end

function OrderedSet:pushback(item)
	local last = self[LastTag]
	if addto(self, item, last) == item then
		self[LastTag] = item
		return item
	end
end

local sequence = OrderedSet.sequence
function OrderedSet:__tostring()
	local result = { "[ " }
	for item in sequence(self) do
		result[#result+1] = tostring(item)
		result[#result+1] = ", "
	end
	local last = #result
	result[last] = (last == 1) and "[]" or " ]"
	return concat(result)
end

-- set aliases
OrderedSet.add = OrderedSet.pushback

-- stack aliases
OrderedSet.push = OrderedSet.pushfront
OrderedSet.pop = OrderedSet.popfront
OrderedSet.top = OrderedSet.first

-- queue aliases
OrderedSet.enqueue = OrderedSet.pushback
OrderedSet.dequeue = OrderedSet.popfront
OrderedSet.head = OrderedSet.first

return OrderedSet
