--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

lru = {}

local Queue = {}

function Queue:remove(entry)
	local prev = entry.prev
	local next = entry.next

	if prev then
		prev.next  = next
		entry.prev = nil
	else -- entry == tail
		self.tail = next
	end

	if next then
		next.prev  = prev
		entry.next = nil
	else -- entry == head
		self.head = prev
	end

	self.size = self.size - 1
end

function Queue:pop()
	self:remove(self.tail)
end

function Queue:is_linked(entry)
	return entry.prev or entry.next or entry == self.head
end

function Queue:push(entry)
	local overflow = false
	if self:is_linked(entry) then
		self:remove(entry)
	elseif self.size == self.max then
		self:pop()
		overflow = true
	end

	if self.size == 0 then
		self.tail = entry
	end

	entry.next = nil
	entry.prev = self.head

	if self.head then
		self.head.next = entry
	end

	self.head = entry
	self.size = self.size + 1
	return overflow
end

function Queue:new(max, overflowcb)
	local queue = {size = 0, max = max or 0, overflowcb = overflowcb}
	setmetatable(queue, self)
	self.__index = self
	return queue
end

local Cache = {__mode = 'v'}

function Cache:new()
	return setmetatable({}, self)
end

function lru.remove(self, key)
	local cache = self.cache
	local entry = cache[key]
	local queue = self.queue

	if entry and queue:is_linked(entry) then
		queue:remove(entry)
	end

	cache[key] = nil
end

local function has_expired(entry, timeout)
	return os.time() - entry.timestamp > timeout
end

function lru.get(self, key)
	local entry = self.cache[key]

	if entry then
		if has_expired(entry, self.timeout) then
			self:remove(key)
		else
			self.queue:push(entry)
			return entry.value
		end
	end
end

function lru.set(self, key, value)
	local cache = self.cache
	local entry = cache[key]

	if value ~= nil then
		entry = entry or {}
		entry.timestamp = os.time()
		entry.value, value = value, entry.value

		if self.queue:push(entry) then self.overflowcb(key, value) end
		cache[key] = entry
	elseif entry then
		self:remove(key)
	end
end

function lru.size(self)
	return self.queue.size
end

lru.__index = function (self, key)
	return lru[key] or lru.get(self, key)
end

lru.__newindex = lru.set

lru.__len = lru.size

local function iterator(t, p)
	local k, v = next(t, p)
	if k then return k, v.value end
end

lru.__pairs = function (t)
	return iterator, t.cache, nil
end

local function empty() end

function lru.new(max, timeout, overflowcb)
	if type(timeout) ~= 'number' then
		timeout = (1 << 63) - 1
	end

	local cache = Cache:new()
	local queue = Queue:new(max, overflowcb)

	local obj = {cache = cache, queue = queue, timeout = timeout,
		overflowcb = overflowcb or empty}
	setmetatable(obj, lru)

	return obj
end

return lru
