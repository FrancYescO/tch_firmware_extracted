-- Project: LOOP Class Library
-- Release: 2.3 beta
-- Title  : Interchangeable Disjoint Cyclic Sets
-- Author : Renato Maia <maia@inf.puc-rio.br>
-- Notes  :
--   Can be used as a module that provides functions instead of methods.
--   Instance of this class should not store the name of methods as values.
--   To avoid the previous issue, use this class as a module on a simple table.
--   Each element is stored as a key mapping to its successor.


local _G = require "_G"
local next = _G.next
local rawget = _G.rawget
local tostring = _G.tostring

local table = require "table"
local concat = table.concat

local tabop = require "loop.table"
local copy = tabop.copy

local oo = require "loop.base"
local class = oo.class


local CyclicSets  = class()

-- { ? }     :contains(item) --> { ? }      : false
-- { item ? }:contains(item) --> { item ? } : true
function CyclicSets:contains(item)
	return self[item] ~= nil
end

-- { ? }           :successor(item) --> { ? }            : nil 
-- { item | ? }    :successor(item) --> { item | ? }     : item
-- { item, succ ? }:successor(item) --> { item, succ ? } : succ
function CyclicSets:successor(item)
	return self[item]
end

local successor = CyclicSets.successor
function CyclicSets:forward(place)
	return successor, self, place
end

-- { ? }              :add()            --> { ? }               : error "table index is nil"
-- { ? }              :add(nil, place)  --> { ? }               : error "table index is nil"
-- { place ? }        :add(nil, place)  --> { place ? }         : error "table index is nil"
-- { ? }              :add(item)        --> { item | ? }        : item
-- { item ? }         :add(item)        --> { item ? }          :
-- { ? }              :add(item, item)  --> { item | ? }        : item
-- { item ? }         :add(item, item)  --> { item ? }          :
-- { ? }              :add(item, place) --> { place, item | ? } : item
-- { place ? }        :add(item, place) --> { place, item ? }   : item
-- { item ? }         :add(item, place) --> { item ? }          :
-- { place, item ? }  :add(item, place) --> { place, item ? }   :
-- { place ? item ?? }:add(item, place) --> { place ? item ?? } :
function CyclicSets:add(item, place)
	if self[item] == nil then
		local succ
		if place == nil then
			place, succ = item, item
		else
			succ = self[place]
			if succ == nil then
				succ = place
			end
		end
		self[item]  = succ
		self[place] = item
		return item
	end
end

-- { ? }            :removefrom()      --> { ? }       :
-- { ? }            :removefrom(place) --> { ? }       :
-- { place | ? }    :removefrom(place) --> { ? }       : place
-- { place, item ? }:removefrom(place) --> { place ? } : item
function CyclicSets:removefrom(place)
	local item = self[place]
	if item ~= nil then
		self[place] = self[item]
		self[item] = nil
		return item
	end
end

-- { ? }             :removeset()     --> { ? } :
-- { ? }             :removeset(item) --> { ? } :
-- { item | ? }      :removeset(item) --> { ? } : item
-- { item..last | ? }:removeset(item) --> { ? } : item
function CyclicSets:removeset(item)
	local succ = self[item]
	if succ ~= nil then
		self[item] = nil
		while succ ~= item do
			succ, self[succ] = self[succ], nil
		end
		return item
	end
end

-- # moving inexistent value
-- { ? }    :movefrom()              --> { ? }     :
-- { ? }    :movefrom(val)           --> { ? }     :
-- { ? }    :movefrom(val, val)      --> { ? }     :
-- { ? }    :movefrom(val, nil, val) --> { ? }     :
-- { ? }    :movefrom(val, val, val) --> { ? }     :
-- { ? }    :movefrom(val, nil, end) --> { ? }     :
-- { ? }    :movefrom(val, val, end) --> { ? }     :
-- { ? }    :movefrom(val, new)      --> { ? }     :
-- { ? }    :movefrom(val, new, end) --> { ? }     :
-- { new ? }:movefrom(val, new)      --> { new ? } :
-- { new ? }:movefrom(val, new, end) --> { new ? } :
-- 
-- # moving value to the same old place
-- { old | ? }        :movefrom(old)            --> { old | ? }         :
-- { old | ? }        :movefrom(old, nil, old)  --> { old | ? }         :
-- { old ? }          :movefrom(old, old)       --> { old ? }           :
-- { old, val ? }     :movefrom(old, old, old)  --> { old, val ? }      :
-- { old, val..end ? }:movefrom(old, old, end)  --> { old, val..end ? } :
-- 
-- # moving value to itself
-- { old, val ? }     :movefrom(old)             --> { old ? | val }      : val
-- { old, val ? }     :movefrom(old, val)        --> { old ? | val }      : val
-- { old, val ? }     :movefrom(old, val, val)   --> { old ? | val }      : val
-- { old, val..end ? }:movefrom(old, nil, end)   --> { old ? | val..end } : val
-- { old, val..end ? }:movefrom(old, val, end)   --> { old ? | val..end } : val
-- 
-- # moving value to an inexistent set
-- { old | ? }        :movefrom(old, new)       --> { new, old | ? }          : old
-- { old | ? }        :movefrom(old, new, old)  --> { new, old | ? }          : old
-- { val..old | ? }   :movefrom(old, new, old)  --> { new, val..old | ? }     : val
-- { old, val ? }     :movefrom(old, new)       --> { old ? | new, val }      : val
-- { old, val ? }     :movefrom(old, new, val)  --> { old ? | new, val }      : val
-- { old, val..end ? }:movefrom(old, new, end)  --> { old ? | new, val..end } : val
--
-- # moving value to a different set
-- { old | new ? }             :movefrom(old, new)       --> { new, old ? }               : old
-- { old | new ? }             :movefrom(old, new, old)  --> { new, old ? }               : old
-- { val..old | new ? }        :movefrom(old, new, old)  --> { new, val..old ? }          : val
-- { old, val ? | new ?? }     :movefrom(old, new)       --> { old ? | new, val ?? }      : val
-- { old, val ? | new ?? }     :movefrom(old, new, val)  --> { old ? | new, val ?? }      : val
-- { old, val..end ? | new ?? }:movefrom(old, new, end)  --> { old ? | new, val..end ?? } : val
--
-- # moving value to a different place in the same set
-- { old, val..new ? }      :movefrom(old, new)       --> { old..new, val ? }       : val
-- { old, val..end...new ? }:movefrom(old, new, end)  --> { old...new, val..end ? } : val
-- 
-- # specifing an end of a sequence that does not belong to the set
-- { old ? }         :movefrom(old, old, end) --> CORRUPTED : ???
-- { old ? }         :movefrom(old, new, end) --> CORRUPTED : ???
-- { old..new ? }    :movefrom(old, new, end) --> CORRUPTED : ???
-- { old ? | new ?? }:movefrom(old, new, end) --> CORRUPTED : ???
-- 
-- # specifing a sequence which values do not belong to the same set
-- { old, val ? | end ?? }          :movefrom(old, nil, end) --> UNKNOWN STATE. MAYBE VALID? : val
-- { old, val ? | end ?? }          :movefrom(old, new, end) --> UNKNOWN STATE. MAYBE VALID? : val
-- { old, val..new ? | end ?? }     :movefrom(old, new, end) --> UNKNOWN STATE. MAYBE VALID? : val
-- { old, val ? | end..new ?? }     :movefrom(old, new, end) --> UNKNOWN STATE. MAYBE VALID? : val
-- { old, val ? | end ?? | new ??? }:movefrom(old, new, end) --> UNKNOWN STATE. MAYBE VALID? : val
--
function CyclicSets:movefrom(oldplace, newplace, lastitem)
	local theitem = self[oldplace]
	if theitem ~= nil then
		if lastitem == nil then lastitem = theitem end
		local oldsucc = self[lastitem]
		local newsucc
		if newplace == nil or newplace == theitem then
			newplace, newsucc = lastitem, theitem
		else
			newsucc = self[newplace]
			if newsucc == nil then
				newsucc = newplace
			end
		end
		if newplace ~= oldplace then
			self[oldplace] = oldsucc
			self[lastitem] = newsucc
			self[newplace] = theitem
			return theitem
		end
	end
end

function CyclicSets:disjoint()
	local result = {}
	local missing = copy(self)
	local start = next(missing)
	while start ~= nil do
		result[#result+1] = start
		local item = start
		repeat
			missing[item] = nil
			item = self[item]
		until item == start
		start = next(missing)
	end
	return result
end

function CyclicSets:__tostring()
	local result = {}
	local missing = copy(self)
	local start = next(missing)
	result[#result+1] = "{ "
	while start ~= nil do
		local item = start
		repeat
			if missing[item] == nil then
				result[#result+1] = "<?>" -- data structure is corrupted!
				result[#result+1] = ""
				break
			end
			result[#result+1] = tostring(item)
			result[#result+1] = ", "
			missing[item] = nil
			item = self[item]
		until item == start
		result[#result] = " | "
		start = next(missing)
	end
	local last = #result
	result[last] = (last == 1) and "{}" or " }"
	return concat(result)
end

return CyclicSets
