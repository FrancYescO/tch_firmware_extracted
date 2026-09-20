-- Project: LOOP - Lua Object-Oriented Programming
-- Release: 3.0 beta
-- Title  : Cached Class Model
-- Author : Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local pairs = _G.pairs
local rawget = _G.rawget
local rawset = _G.rawset
local ipairs = _G.ipairs
local setmetatable = _G.setmetatable
local select = _G.select

local table = require "table"
local unpack = table.unpack or _G.unpack

local tabop = require "loop.table"
local copy = tabop.copy
local clear = tabop.clear

local proto = require "loop.proto"
local clone = proto.clone

local multiple = require "loop.multiple"
local multiple_class = multiple.class
local multiple_getclass = multiple.getclass
local multiple_getmember = multiple.getmember
local multiple_isinstanceof = multiple.isinstanceof
local multiple_members = multiple.members
local multiple_rawnew = multiple.rawnew
local multiple_supers = multiple.supers



local OrderedSet = multiple_class()

function OrderedSet:enqueue(value)
	if self[value] == nil then
		local last = self.last
		if last ~= nil then
			self[last] = value
		end
		self.last = value
	end
end

local function subsiterator(queue, class)
	class = queue[class]
	if class ~= nil then
		for sub in pairs(class.subs) do
			queue:enqueue(sub)
		end
		return class
	end
end

local function subs(class)
	local queue = OrderedSet()
	queue:enqueue(class)
	return subsiterator, queue, "last"
end

local CachedClass

local function getcached(class)
	local cached = multiple_getclass(class)
	if multiple_isinstanceof(cached, CachedClass) then
		return cached
	end
end



local function class(class, ...)
	class = getcached(class) or CachedClass(class)
	class:updatehierarchy(...)
	class:updateinheritance()
	return class.proxy
end

local function rawnew(class, object)
	local cached = getcached(class)
	if cached then class = cached.class end
	return multiple_rawnew(class, object)
end

local function new(class, ...)
	local new = class.__new
	if new ~= nil then
		return new(class, ...)
	end
	return rawnew(class, ...)
end

local function getclass(object)
	local class = multiple_getclass(object)
	return class ~= nil and class.__class or class
end

local function isclass(class)
	return getcached(class) ~= nil
end

local function getsuper(class)
	local supers = {}
	local cached = getcached(class)
	if cached then
		for index, super in ipairs(cached.supers) do
			supers[index] = super.proxy
		end
		class = cached.class
	end
	for _, super in multiple_supers(class) do
		supers[#supers + 1] = super
	end
	return unpack(supers)
end

local function icached(cached, index)
	local super
	local supers = cached.supers
	index = index + 1
	-- check if index points to a cached superclass
	super = supers[index]
	if super then return index, super.proxy end
	-- check if index points to an uncached superclass
	super = cached.uncached[index - #supers]
	if super then return index, super end
end
local function supers(class)
	local cached = getcached(class)
	if cached
		then return icached, cached, 0
		else return multiple_supers(class)
	end
end

local function issubclassof(class, super)
	if class == super then return true end
	for _, superclass in supers(class) do
		if issubclassof(superclass, super) then return true end
	end
	return false
end

local function isinstanceof(object, class)
	return issubclassof(getclass(object), class)
end

local function getmember(class, name)
	local cached = getcached(class)
	if cached
		then return cached.members[name]
		else return multiple_getmember(class, name)
	end
end

local function members(class)
	local cached = getcached(class)
	if cached
		then return pairs(cached.members)
		else return multiple_members(class)
	end
end

local function allmembers(class)
	local cached = getcached(class)
	if cached
		then return pairs(cached.class)
		else return multiple_members(class)
	end
end



local oo = {
	OrderedSet = OrderedSet, -- for extension packages (see 'scoped')
	subs = subs,             -- for extension packages (see 'scoped')
	getcached = getcached,   -- for extension packages (see 'scoped')
	
	class = class,
	rawnew = rawnew,
	new = new,
	getclass = getclass,
	isclass = isclass,
	
	getsuper = getsuper,
	supers = supers,
	issubclassof = issubclassof,
	
	isinstanceof = isinstanceof,
	
	getmember = getmember,
	members = members,
	allmembers = allmembers,
}



CachedClass = multiple_class({}, oo)

local function proxy_newindex(proxy, field, value)
	return multiple_getclass(proxy):updatefield(field, value)
end
function CachedClass:__new(class)
	local meta = {}
	local copied = (class == nil) and {} or copy(class)
	local proxy = (class == nil) and {} or clear(class)
	self = multiple_rawnew(self, {
		__call = new,
		__index = meta,
		__newindex = proxy_newindex,
		__pairs = members,
		supers = {},
		subs = {},
		members = copied,
		class = meta,
		proxy = proxy,
	})
	setmetatable(proxy, self)
	meta.__class = proxy
	return self
end

function CachedClass:updatehierarchy(...)
	-- separate cached from non-cached classes
	local caches = {}
	local supers = {}
	for i = 1, select("#", ...) do
		local super = select(i, ...)
		local cached = getcached(super)
		if cached
			then caches[#caches + 1] = cached
			else supers[#supers + 1] = super
		end
	end
	-- remove it from its old superclasses
	for _, super in ipairs(self.supers) do
		super:removesubclass(self)
	end
	-- update superclasses
	self.uncached = supers
	self.supers = caches
	-- register as subclass in all superclasses
	for _, super in ipairs(self.supers) do
		super:addsubclass(self)
	end
end

function CachedClass:updateinheritance()
	-- relink all affected classes
	for sub in subs(self) do
		sub:updatemembers()
		sub:updatesuperclasses()
	end
end

function CachedClass:addsubclass(class)
	self.subs[class] = true
end

function CachedClass:removesubclass(class)
	self.subs[class] = nil
end

function CachedClass:updatesuperclasses()
	local uncached = {}
	-- copy uncached superclasses defined in the class
	for _, super in ipairs(self.uncached) do
		if not uncached[super] then
			uncached[super] = true
			uncached[#uncached + 1] = super
		end
	end
	-- copy inherited uncached superclasses
	for _, cached in ipairs(self.supers) do
		for _, super in multiple_supers(cached.class) do
			if not uncached[super] then
				uncached[super] = true
				uncached[#uncached + 1] = super
			end
		end
	end
	multiple_class(self.class, unpack(uncached))
end

function CachedClass:updatemembers()
	local class = clear(self.class)
	for i = #self.supers, 1, -1 do
		local super = self.supers[i].class
		-- copy inherited members
		copy(super, class)
		-- do not copy the default __index value
		if rawget(class, "__index") == super then
			rawset(class, "__index", nil)
		end
	end
	-- copy members defined in the class
	copy(self.members, class)
	-- set the default __index value
	if rawget(class, "__index") == nil then
		rawset(class, "__index", class)
	end
	-- set class proxy as the result of getclass function
	class.__class = self.proxy
end

function CachedClass:updatefield(name, member)
	-- update member list
	local members = self.members
	members[name] = member

	-- get old linkage
	local class = self.class
	local old = class[name]
	
	-- replace old linkage for the new one
	class[name] = member
	local queue = OrderedSet()
	local current = self
	queue:enqueue(self)
	for sub in pairs(self.subs) do
		queue:enqueue(sub)
	end
	repeat
		current = queue[current]
		if current == nil then break end
		class = current.class
		members = current.members
		if members[name] == nil then
			for _, super in ipairs(current.supers) do
				local superclass = super.class
				if superclass[name] ~= nil then
					if superclass[name] ~= class[name] then
						class[name] = superclass[name]
						for sub in pairs(current.subs) do
							queue:enqueue(sub)
						end
					end
					break
				end
			end
		end
	until false
	return old
end

oo.CachedClass = CachedClass -- for extension packages (see 'scoped')


return oo
