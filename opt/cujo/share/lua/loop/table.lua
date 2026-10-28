-- Project: LOOP - Lua Object-Oriented Programming
-- Release: 3.0 beta
-- Title  : Utility Functions for Table Manipulation
-- Author : Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local next = _G.next
local rawset = _G.rawset
local setmetatable = _G.setmetatable

local table = {}

function table.copy(source, destiny)
	if destiny == nil then destiny = {} end
	for key, value in next, source do
		rawset(destiny, key, value)
	end
	return destiny
end

function table.clear(table)
	for key in next, table do
		rawset(table, key, nil)
	end
	return table
end

function table.memoize(func, weak)
	return setmetatable({}, {
		__mode = weak,
		__index = function(self, input)
			local output = func(input)
			if output ~= nil then
				self[input] = output
			end
			return output
		end,
	})
end

return table
