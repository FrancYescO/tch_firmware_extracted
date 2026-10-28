local _G = require "_G"
local assert = _G.assert
local type = _G.type

local array = require "table"
local insert = array.insert
local remove = array.remove

local math = require "math"
local floor = math.floor
local inf = math.huge

local event = require "coutil.event"
local emitevent = event.emitall
local pendingevent = event.pending

local function sortedinsert(list, value, i, j)
	if i > j then
		return insert(list, i, value)
	else
		local m = floor((i+j)/2)
		local pivot = list[m]
		if value < pivot then
			return sortedinsert(list, value, i, m-1)
		elseif value > pivot then
			return sortedinsert(list, value, m+1, j)
		end
	end
end

local function sortedremove(list, value, i, j)
	if i <= j then
		local m = floor((i+j)/2)
		local pivot = list[m]
		if value < pivot then
			return sortedremove(list, value, i, m-1)
		elseif value > pivot then
			return sortedremove(list, value, m+1, j)
		else
			return remove(list, m)
		end
	end
end

local waketimes = {}

local function setuptimer(timestamp)
	assert(type(timestamp) == "number", "bad argument #1 (number expected)")
	if timestamp ~= inf then
		sortedinsert(waketimes, timestamp, 1, #waketimes)
	end
end

local module = { create = setuptimer }

function module.cancel(timestamp)
	assert(type(timestamp) == "number", "bad argument #1 (number expected)")
	if not pendingevent(timestamp) then
		sortedremove(waketimes, timestamp, 1, #waketimes)
		return true
	end
	return false
end

function module.emitall(timestamp)
	while waketimes[1] ~= nil and waketimes[1] <= timestamp do
		emitevent(remove(waketimes, 1))
	end
	return waketimes[1]
end

function module.nextwake()
	return waketimes[1]
end

return module
