-- Copyright (c) 2020 CUJO LLC. All rights reserved.
-- Copyright (c) 2015 2015 Boris Nagaev

--[[

The MIT License (MIT)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]

-- Standard luacheck globals stanza based on what NFLua preloads and
-- the order in which cujo.nf loads these scripts.
--
-- luacheck: read globals config data
-- luacheck: read globals base64 json timer
-- luacheck: read globals debug debug_logging
-- luacheck: globals lru
-- luacheck: read globals nf
-- luacheck: read globals threat
-- luacheck: read globals conn
-- luacheck: read globals safebro sbconfig
-- luacheck: read globals ssl
-- luacheck: read globals http
-- (caps exports no globals)
-- (tcptracker exports no globals)
-- (apptracker exports no globals)
-- luacheck: read globals p0f_httpsig p0f_tcpsig
-- (httpcap exports no globals)
-- (tcpcap exports no globals)
-- luacheck: read globals appblocker
-- luacheck: read globals gquic
-- luacheck: read globals dns
-- (ssdpcap exports no globals)

-- LRU-ordered queue/table:
--
-- * On each lookup by index, the returned entry is either removed if it has
--   timed out (by os.time()) or moved to the head of the queue if it has not.
--
-- * A maximum size can be set. Insertions when the maximum is reached result in
--   the oldest element being replaced.
lru = {}

--local map = {}

-- indices of tuple
local VALUE = 1
local PREV = 2
local NEXT = 3
local KEY = 4
local TIME = 5



-- remove a tuple from linked list
local function cut(list, tuple)
    local tuple_prev = tuple[PREV]
    local tuple_next = tuple[NEXT]
    tuple[PREV] = nil
    tuple[NEXT] = nil
    if tuple_prev and tuple_next then
        tuple_prev[NEXT] = tuple_next
        tuple_next[PREV] = tuple_prev
    elseif tuple_prev then
        -- tuple is the oldest element
        tuple_prev[NEXT] = nil
        list.oldest = tuple_prev
    elseif tuple_next then
        -- tuple is the newest element
        tuple_next[PREV] = nil
        list.newest = tuple_next
    else
        -- tuple is the only element
        list.newest = nil
        list.oldest = nil
    end

end

-- insert a tuple to the newest end
local function setNewest(list, tuple)
    if not list.newest then
        list.newest = tuple
        list.oldest = tuple
    else
        tuple[NEXT] = list.newest
        list.newest[PREV] = tuple
        list.newest = tuple
    end
end

local function del(self, key, tuple)
    self.map[key] = nil
    cut(self.list, tuple)
    self.size = self.size - 1
    self.list.removed_tuple = tuple
end

-- removes elemenets to provide enough memory
-- returns last removed element or nil
local function makeFreeSpace(self)
    while self.size + 1 > self.max_size
    do
        if self.overflowcb then
            self.overflowcb(self.list.oldest[KEY], self.list.oldest[VALUE])
        end
        assert(self.list.oldest, "not enough storage for cache")
        del(self, self.list.oldest[KEY], self.list.oldest)
    end
end


local function has_expired(self, tuple)
    return self.timeout ~= nil and os.time() - tuple[TIME] > self.timeout
end


function lru.get(self, key)
    local tuple = self.map[key]
    if not tuple then
        return nil
    end
    if has_expired(self, tuple) then
        cut(self.list, tuple)
        return nil
    end
    cut(self.list, tuple)
    setNewest(self.list, tuple)
    return tuple[VALUE]
end

function lru.set(self, key, value)
    local tuple = self.map[key]
    if tuple then
        -- this self.list.next_t is needed to keep track of next tuple in case 
        -- current one would be removed during for loop iteration
        self.list.next_t = self.map[key][PREV]
        del(self, key, tuple)
    end
    if value ~= nil then
        -- the value is not removed
        makeFreeSpace(self)
        local tuple1 = self.list.removed_tuple or {}
        self.map[key] = tuple1
        tuple1[VALUE] = value
        tuple1[KEY] = key
        tuple1[TIME] = os.time()

        self.size = self.size + 1
        setNewest(self.list, tuple1)
    else
        assert(key ~= nil, "Key may not be nil")
    end
    self.list.removed_tuple = nil

    if self.debug and self.queue_statecb then
        self.queue_statecb(self.cache_name,os.time(),self.size)
    end
end

function lru.remove(self, key)
    return lru.set(self, key, nil)
end

function lru.size(self)
    return self.size
end

function lru.enable_debug(self)
    self.debug = true
end

function lru.disable_debug(self)
    self.debug = false
end

local function mynext(self, next_key)
    local tuple
    if next_key then
        if self.map[next_key] == nil then
            tuple = self.list.next_t
        else
          tuple = self.map[next_key][PREV]
        end
    else
        tuple = self.list.oldest
    end
    if tuple then
        if has_expired(self, tuple) then
            while true do
                if not has_expired(self, tuple) then
                    return tuple[KEY], tuple[VALUE]
                end
                local curr_tuple = self.map[tuple[KEY]][PREV]
                if not curr_tuple then
                    return nil
                end
                del(self, tuple[KEY],tuple)
                tuple = curr_tuple
            end
        else
            return tuple[KEY], tuple[VALUE]
        end
    else
        return nil
    end
end

-- returns iterator for keys and values
local function lru_pairs(self)
    return mynext,self, nil, nil
end

lru.__newindex = function (self, key, value)
    return lru.set(self, key , value)
end

lru.pairs = function (self)
    return lru_pairs(self)
end

lru.__index = function (self, key)
    return lru[key] or lru.get(self, key)
end

lru.__pairs = function (self)
    return lru_pairs(self)
end

lru.__len = function (self)
    return lru.size(self)
end



function lru.new(_max_size, _timeout, _overflowcb, _queue_statecb, _cache_name)

    assert(_max_size >= 1, "max_size must be >= 1")

    if _timeout and type(_timeout) ~= 'number' then
        error('timeout is set wrongly :',_timeout)
    end

    if _overflowcb and type(_overflowcb) ~= 'function' then
        error('overflowcb is set wrongly :',_overflowcb)
    end

    if _queue_statecb and type(_queue_statecb) ~= 'function' then
        error('queue_statecb is set wrongly :',_queue_statecb)
    end

    local map = {}

    local list = {
        newest = nil,
        oldest = nil,
        removed_tuple = nil,
        next_t = nil
    }

    local obj = {
        map = {},
        list = list,
        size = 0,
        max_size = _max_size,
        timeout = _timeout,
        overflowcb = _overflowcb,
        queue_statecb = _queue_statecb,
        cache_name = _cache_name,
        debug = false,
    }

    return setmetatable(obj,lru)
end

return lru
