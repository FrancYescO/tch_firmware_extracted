-- Project: LOOP - Lua Object-Oriented Programming
-- Release: 3.0 beta
-- Title  : Scoped Class Model
-- Author : Renato Maia <maia@inf.puc-rio.br>
--------------------------------------------------------------------------------
-- TODO:
--	 Test replacement of all members of a scope by ClassProxy[scope] = { ... }
--	 Test static method call.
--	 Define a default __eq metamethod that compares the object references.
--	 The best way to relink member with numeric, string and boolean values.
--	 Replace conditional compiler by static function constructors.
--------------------------------------------------------------------------------

local _G = require "_G"                                                         -- [[VERBOSE]] local verbose = require "loop.verbose"
local assert = _G.assert
local getmetatable = _G.getmetatable
local ipairs = _G.ipairs
local load = _G.load
local pairs = _G.pairs
local rawget = _G.rawget
local rawset = _G.rawset
local setmetatable = _G.setmetatable
local type = _G.type

local table = require "table"
local concat = table.concat

local tabop = require "loop.table"
local copy = tabop.copy
local clear = tabop.clear
local memoize = tabop.memoize

local proto = require "loop.proto"
local clone = proto.clone

local multiple = require "loop.multiple"
local multiple_class = multiple.class
local multiple_isinstanceof = multiple.isinstanceof

local cached = require "loop.cached"
local getclass = cached.getclass
local CachedClass = cached.CachedClass



local OrderedSet = multiple_class()

function OrderedSet:insert(value, place)
	if self[value] == nil then
		self[value] = self[place]
		self[place] = value
	end
end

-- maps private and protected state objects to the object (public) table
local Object = setmetatable({}, { __mode = "kv" })

local function ProtectedPool(members)                                           -- [[VERBOSE]] verbose:scoped "new protected pool"
	local class = multiple_class(members)
	local pool = memoize(function(object)                                         -- [[VERBOSE]] verbose:scoped("new 'protected' for 'public' ",object)
		local protected = class()
		Object[protected] = object
		return protected
	end, "k")
	pool.class = class
	return pool
end

local function PrivatePool(members)                                             -- [[VERBOSE]] verbose:scoped{"new private pool", members = members}
	local class = multiple_class(members)
	local pool
	pool = memoize(function(outter)                                               -- [[VERBOSE]] verbose:scoped("new 'protected' for 'public' ",object)
		local object = Object[outter]                                               -- [[VERBOSE]] verbose:scoped("'public' is ",object or outter)
		local private = rawget(pool, object)
		if private == nil then
			private = class()                                                         -- [[VERBOSE]] verbose:scoped("new 'private' created: ",private)
			if object == nil then
				Object[private] = outter                                                -- [[VERBOSE]] verbose:scoped("'public' ",outter," registered for the new 'private' ",private)
			else
				Object[private] = object                                                -- [[VERBOSE]] verbose:scoped("'public' ",object," registered for the new 'private' ",private)
				pool[object] = private                                                  -- [[VERBOSE]] verbose:scoped("new 'private' ",private," stored at the pool for 'public' ",object)
			end                                                                       -- [[VERBOSE]] else verbose:scoped("reusing 'private' ",private," associated to 'public'")
		end                                                                         -- [[VERBOSE]] verbose:scoped(false, "returning 'private' ",private," for reference ",outter)
		return private
	end, "k")
	pool.class = class
	return pool
end

local function bindto(class, member)
	if type(member) == "function" then                                            -- [[VERBOSE]] verbose:scoped("new method closure for ",member)
		local method = member
		member = function (self, ...)
			local pool = rawget(class, getmetatable(self))                            -- [[VERBOSE]] verbose:scoped("method call on reference ",self," (pool: ",pool,")")
			if pool == nil
				then return method(self, ...)
				else return method(pool[self], ...)
			end
		end
	end
	return member
end
--------------------------------------------------------------------------------
local IndexerMap = setmetatable({}, { __mode = "k"})
local IndexerCode = {
	{[[local Public   = select(1, ...)                      ]],"private or protected" },
	{[[local meta     = select(2, ...)                      ]],"not (newindex and public and nilindex)" },
	{[[local class    = select(3, ...)                      ]],"newindex or private" },
	{[[local bindto   = select(4, ...)                      ]],"newindex" },
	{[[local newindex = select(5, ...)                      ]],"newindex and not nilindex" },
	{[[local index    = select(5, ...)                      ]],"index and not nilindex" },
	{[[local registry = class.registry                      ]],"private" },
	{[[local result                                         ]],"index and (private or protected)" },
	{[[return function (state, name, value)                 ]],"newindex" },
	{[[return function (state, name)                        ]],"index" },
	{[[	result = meta[name]                                 ]],"index and (private or protected)" },
	{[[	return   meta[name]                                 ]],"index and public" },
	{[[	         or index[name]                             ]],"index and tableindex" },
	{[[	         or index(state, name)                      ]],"index and functionindex" },
	{[[	if result == nil then                               ]],"index and (private or protected)" },
	{[[	if meta[name] == nil then                           ]],"newindex and (private or protected or not nilindex)" },
	{[[		state = Public[state]                             ]],"private or protected" },
	{[[		local Protected = registry[getmetatable(state)]   ]],"private" },
	{[[		if Protected then state = Protected[state] end    ]],"private" },
	{[[		return state[name]                                ]],"index and (private or protected)" },
	{[[		state[name] = bindto(class, value)                ]],"newindex and (private or protected) and nilindex" },
	{[[		newindex[name] = bindto(class, value)             ]],"newindex and tableindex" },
	{[[		return newindex(state, name, bindto(class, value))]],"newindex and functionindex" },
	{[[	else                                                ]],"newindex and (private or protected or not nilindex)" },
	{[[		return rawset(state, name, bindto(class, value))  ]],"newindex" },
	{[[	end                                                 ]],"private or protected or (newindex and not nilindex)" },
	{[[	return result                                       ]],"index and (private or protected)" },
	{[[end                                                  ]]},
}
local IndexerFactory = memoize(function(name)
	local includes = {}
	for tag in name:gmatch("[^%s]+") do
		includes[tag] = true
	end
	local func = {}
	for line, strip in ipairs(IndexerCode) do
		local cond = strip[2]
		if cond then
			cond = assert(load("return "..cond,
				"compiler condition "..line..":", "t", includes))()
		else
			cond = true
		end
		if cond then
			assert(type(strip[1]) == "string",
				"code string is not a string")
			func[#func+1] = strip[1]
		end
	end
	return load(concat(func, "\n"), name)
end)
local function wrapindexer(class, scope, action)
	local meta = class:getmeta(scope)
	local index = meta["__"..action]
	local name = scope.." "..action.." "..type(index).."index"
	local factory = IndexerFactory[name]
	local wrapper = factory(Object, meta, class, bindto, index)
	IndexerMap[wrapper] = index
	return wrapper
end

local function unwrapindexer(meta, tag)
	local indexer
	local key = "__"..tag
	local func = assert(meta[key], "no indexer found in scoped class metatable.")
	return IndexerMap[func]
end
--------------------------------------------------------------------------------
local function supersiterator(stack, class)
	class = stack[class]
	if class then
		for _, super in ipairs(class.supers) do
			stack:insert(super, class)
		end
		return class
	end
end
local function hierarchyof(class)
	local stack = OrderedSet{ class }
	return supersiterator, stack, 1
end
--------------------------------------------------------------------------------
local function this(object)
	return Object[object] or object
end

local function priv(object, class)
	if class == nil then class = getclass(object) end
	class = getclass(class)
	if class and class.private then
		if getclass(object) == class.private.class
			then return object                 -- private object
			else return class.private[object]  -- protected or public object
		end
	end
end

local function prot(object)
	local class = getclass(getclass(object))
	if class and class.protected then
		if getclass(object) == class.protected.class
			then return object                         -- protected object
			else return class.protected[this(object)]  -- private or public object
		end
	end
end
--------------------------------------------------------------------------------
local function publicproxy_call(_, object)
	return this(object)
end

local function protectedproxy_call(_, object)
	return prot(object)
end

local function privateproxy_call(_, object, class)
	return priv(object, class)
end
--------------------------------------------------------------------------------
local ScopedClass = multiple_class({}, CachedClass)

function ScopedClass:getmeta(scope)
	return self[scope] and self[scope].class
	         or
	       (scope == "public") and self.class
	         or
	       nil
end

function ScopedClass:getmembers(scope)
	return self.members[scope]
end

function ScopedClass:__new(class)
	if class == nil then class = { public = {} } end
	
	-- adjust class definition to use scoped member tables
	if type(class.public) ~= "table" then
		if
			(type(class.protected) == "table")
				or
			(type(class.private) == "table")
		then
			class.public = {}
		else
			local public = copy(class)
			clear(class)
			class.public = public
		end
	end

	-- initialize scoped cached class
	self = CachedClass.__new(self, class)
	self.registry = { [self.class] = false }

	-- define scoped class proxy for public state
	rawset(self.proxy, "public", setmetatable({}, {
		__call = publicproxy_call,
		__index = self.class,
		__newindex = function(_, field, value)
			self:updatefield(field, value, "public")
		end,
	}))

	return self
end

function ScopedClass:addsubclass(class)
	CachedClass.addsubclass(self, class)

	local public = class.class
	for super in hierarchyof(self) do
		local registry = super.registry
		if registry then -- if super is a scoped class
			registry[public] = false
			super[public] = super.private
		end
	end
end

function ScopedClass:removesubclass(class)
	CachedClass.removesubclass(self, class)

	local public = self.class
	local protected = self:getmeta("protected")
	local private = self:getmeta("private")

	for super in hierarchyof(self) do
		local registry = super.registry
		if registry then -- if super is a scoped class
			registry[public] = nil
			super[public] = nil
			if protected then
				registry[protected] = nil
				super[protected] = nil
			end
			if private then
				registry[private] = nil
				super[private] = nil
			end
		end
	end
end

local function copymembers(class, source, destiny)
	if source then
		if not destiny then destiny = {} end
		for field, value in pairs(source) do
			destiny[field] = bindto(class, value)
		end
	end
	return destiny
end
function ScopedClass:updatemembers()
	--
	-- metatables to collect with current members
	--
	local public = clear(self.class)
	local protected
	local private
	
	--
	-- copy inherited members
	--
	local publicindex, publicnewindex
	local protectedindex, protectednewindex
	local superclasses = self.supers
	for i = #superclasses, 1, -1 do
		local super = superclasses[i]

		-- copy members from superclass metatables
		public = copy(super.class, public)

		if multiple_isinstanceof(super, ScopedClass) then
			-- copy protected members from superclass metatables
			protected = copy(super:getmeta("protected"), protected)

			-- extract the __index and __newindex values
			publicindex    = unwrapindexer(public, "index")    or publicindex
			publicnewindex = unwrapindexer(public, "newindex") or publicnewindex
			if protected then
				protectedindex    = unwrapindexer(protected, "index")    or protectedindex
				protectednewindex = unwrapindexer(protected, "newindex") or protectednewindex
			end
		end
	end
	public.__index    = publicindex
	public.__newindex = publicnewindex
	if protected then
		protected.__index    = protectedindex
		protected.__newindex = protectednewindex
	end

	--
	-- copy members defined in the class
	--
	public    = copymembers(self, self.members.public,    public)
	protected = copymembers(self, self.members.protected, protected)
	private   = copymembers(self, self.members.private,   private)

	--
	-- setup public metatable with proper indexers
	--
	public.__index = wrapindexer(self, "public", "index")
	public.__newindex = wrapindexer(self, "public", "newindex")
	
	--
	-- setup proper protected state features: pool, proxy and indexers
	--
	if protected then
		if not self.protected then
			-- create state object pool and class proxy for protected state
			self.protected = ProtectedPool(protected)
			rawset(self.proxy, "protected", setmetatable({}, {
				__call = protectedproxy_call,
				__index = protected,
				__newindex = function(_, field, value)
					self:updatefield(field, value, "protected")
				end,
			}))
			-- register new pool in superclasses
			local protected_pool = self.protected
			for super in hierarchyof(self) do
				local registry = super.registry
				if registry then
					registry[public] = protected_pool
					registry[protected] = false
	
					local pool = super.private
					if pool then
						super[public] = pool
						super[protected] = pool
					else
						super[public] = protected_pool
					end
				end
			end
		else
			-- update current metatable with new members
			protected = copy(protected, clear(self.protected.class))
		end

		-- setup metatable with proper indexers
		protected.__index = wrapindexer(self, "protected", "index")
		protected.__newindex = wrapindexer(self, "protected", "newindex")

	elseif self.protected then
		-- remove old pool from registry in superclasses
		local protected_pool = self.protected
		for super in hierarchyof(self) do
			local registry = super.registry
			if registry then
				registry[public] = false
				registry[protected_pool.class] = nil
	
				super[public] = super.private
				super[protected_pool.class] = nil
			end
		end
		-- remove state object pool and class proxy for protected state
		self.protected = nil
		rawset(self.proxy, "protected", nil)
	end
	
	--
	-- setup proper private state features: pool, proxy and indexers
	--
	if private then
		if not self.private then
			-- create state object pool and class proxy for private state
			self.private = PrivatePool(private)
			rawset(self.proxy, "private", setmetatable({}, {
				__call = privateproxy_call,
				__index = private,
				__newindex = function(_, field, value)
					self:updatefield(field, value, "private")
				end
			}))
			-- registry new pool in superclasses
			local private_pool = self.private
			local pool = self.protected or Object
			for _, super in ipairs(superclasses) do
				for class in hierarchyof(super) do
					local registry = class.registry
					if registry then -- if class is a scoped class
						registry[private] = pool
						class[private] = class.private_pool or pool
					end
				end
			end
			for meta in pairs(self.registry) do
				self[meta] = private_pool
			end
		else
			-- update current metatable with new members
			private = copy(private, clear(self:getmeta("private")))
		end

		-- setup metatable with proper indexers
		private.__index = wrapindexer(self, "private", "index")
		private.__newindex = wrapindexer(self, "private", "newindex")

	elseif self.private then
		-- remove old pool from registry in superclasses
		local private_pool = self.private
		for _, super in ipairs(superclasses) do
			for class in hierarchyof(super) do
				local registry = class.registry
				if registry then -- if class is a scoped class
					registry[private_pool.class] = nil
					class[private_pool.class] = nil
				end
			end
		end
		for meta, pool in pairs(self.registry) do
			self[meta] = pool or nil
		end
		-- remove state object pool and class proxy for private state
		self.private = nil
		rawset(self.proxy, "private", nil)
	end
end

function ScopedClass:updatefield(name, member, scope)                           -- [[VERBOSE]] verbose:scoped(true, "updating field ",name," on scope ",scope," with value ",member)
	member = bindto(self, member)
	if not scope then
		if
			(
				name == "public"
					or
				name == "protected"
					or
				name == "private"
			) and (
				member == nil
					or
				type(member) == "table"
			)
		then                                                                        -- [[VERBOSE]] verbose:scoped("updating scope field")
			self.members[name] = member
			return self:updatemembers()                                               -- [[VERBOSE]] , verbose:scoped(false, "whole scope field updated")
		end
		scope = "public"
	end

	-- Update member list
	local members = self:getmembers(scope)
	members[name] = member

	-- Create new member linkage and get old linkage
	local metatable = self:getmeta(scope)
	local old = metatable[name]
	
	-- Replace old linkage for the new one
	metatable[name] = member
	if scope ~= "private" then
		local queue = OrderedSet()
		local current = self
		queue:enqueue(self)
		for sub in pairs(self.subs) do
			queue:enqueue(sub)
		end
		repeat
			local current = queue[current]
			if current == nil then break end
			metatable = current:getmeta(scope)
			members = current:getmembers(scope)
			if members and (members[name] == nil) then
				for _, super in ipairs(current.supers) do
					local super_meta = super:getmeta(scope)
					if super_meta[name] ~= nil then
						if super_meta[name] ~= metatable[name] then
							metatable[name] = super_meta[name]
							for sub in pairs(current.subs) do
								queue:enqueue(sub)
							end
						end
						break
					end
				end
			end
		until false
	end                                                                           -- [[VERBOSE]] verbose:scoped(false, "field updated")
	return old
end

--------------------------------------------------------------------------------

local oo = clone(cached, {
	this = this,
	prot = prot,
	priv = priv,
})

function oo.class(class, ...)
	class = getclass(class) or ScopedClass(class)
	class:updatehierarchy(...)
	class:updateinheritance()
	return class.proxy
end


return oo
