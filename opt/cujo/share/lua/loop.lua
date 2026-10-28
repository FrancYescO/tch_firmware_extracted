-- Project: LOOP - Lua Object-Oriented Programming
-- Release: 3.0 beta
-- Title  : General Instrospection Operations for LOOP Classes and Objects
-- Author : Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local pairs = _G.pairs
local getmetatable = _G.getmetatable

local getsuper -- initialized below
local supers -- initialized below

local function isingle(single, index)
	if single ~= nil and index == nil then
		return 1, single
	end
end

local function getclass(object)
	local class = getmetatable(object)
	return class ~= nil and class.__class or class
end

local function issubclassof(class, super)
	if class == super then return true end
	for _, base in supers(class) do
		if issubclassof(base, super) then
			return true
		end
	end
	return false
end

local ClassOps = {
	new = false,
	rawnew = false,
	getmember = false,
	members = false,
	getsuper = function() end,
	supers = function(class)
		return isingle, getsuper(class)
	end,
}

local oo = {
	getclass = getclass,
	issubclassof = issubclassof,
}

for name, default in pairs(ClassOps) do
	oo[name] = function(class, ...)
		local meta = getmetatable(class)
		local method = meta and meta[name]
		if method == nil and default then
			method = default
		end
		return method(class, ...)
	end
end

getsuper = oo.getsuper -- declared above
supers = oo.supers -- declared above

function oo.isclass(object)
	local meta = getmetatable(object)
	if meta == nil then return false end
	for name, default in pairs(ClassOps) do
		if meta[name] == nil and not default then
			return false
		end
	end
	return true
end

function oo.isinstanceof(object, class)
	return issubclassof(getclass(object), class)
end

return oo
