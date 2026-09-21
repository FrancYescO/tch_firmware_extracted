-- Project: LOOP Class Library
-- Title  : Map where Least Recently Indexed Entries are Discarded
-- Author : Renato Maia <maia@inf.puc-rio.br>


local base = require "loop.base"
local class = base.class
local rawnew = base.rawnew

local BiCyclicSets = require "loop.collection.BiCyclicSets"
local add = BiCyclicSets.add
local contains = BiCyclicSets.contains
local move = BiCyclicSets.move
local predecessor = BiCyclicSets.predecessor
local removefrom = BiCyclicSets.removefrom
local successor = BiCyclicSets.successor


local function leastused(self, key)
	if key ~= self.last then
		if key == nil then
			key = self.last
		end
		return successor(self.keys, key)
	end
end

local function mostused(self, key)
	if key == nil then
		key = self.last
	else
		key = predecessor(self.keys, key)
		if key == self.last then return end
	end
	return key
end


local LRU = class{
	maxsize = 128,
	size = 0,
	retrieve = function() end,
}

function LRU:__new(...)
	self = rawnew(self, ...)
	if self.map == nil then self.map = {} end
	if self.keys == nil then self.keys = {} end
	return self
end

function LRU:usedkeys(least)
	return least and leastused or mostused, self
end

function LRU:rawget(key)
	return self.map[key]
end

function LRU:get(key)
	local maxsize = self.maxsize
	if maxsize < 1 then return self.retrieve(key) end
	local map = self.map
	local keys = self.keys
	local last = self.last
	local value = map[key]
	if not contains(keys, key) then
		value = self.retrieve(key)
		add(keys, key, last)
		local size = self.size
		if size < maxsize then
			self.size = size+1
		else
			map[removefrom(keys, key)] = nil
		end
		map[key] = value
	elseif key ~= last then
		move(keys, key, last)
	end
	self.last = key
	return value
end

function LRU:put(key, value)
	local maxsize = self.maxsize
	if maxsize < 1 then return end
	local map = self.map
	local keys = self.keys
	local last = self.last
	self.last = key
	value, map[key] = map[key], value
	if not contains(keys, key) then
		add(keys, key, last)
		local size = self.size
		if size < maxsize then
			self.size = size+1
		else
			key = removefrom(keys, key)
			value, map[key] = map[key], nil
		end
	elseif key ~= last then
		move(keys, key, last)
	end
	return key, value
end

function LRU:remove(key)
	local keys = self.keys
	local previous = predecessor(keys, key)
	if previous ~= nil then
		-- remove key from usage list
		removefrom(keys, previous)
		if key == self.last then
			if key == previous then
				self.last = nil
			else
				self.last = previous
			end
		end
		-- update size
		self.size = self.size-1
		-- remove entry from the map
		local map = self.map
		local value = map[key]
		map[key] = nil
		return key, value
	end
end

return LRU
