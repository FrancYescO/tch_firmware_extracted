--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local setmetatable, pairs, pcall, type, assert, tostring =
      setmetatable, pairs, pcall, type, assert, tostring
local logger = require("transformer.logger")

local Lock = {}
Lock.__index = Lock

local function newLock(name)
  local lock = {
    name = name,
    lockCount = 0,
    notifyPending = false,
    listeners = {}
  }
  return setmetatable(lock, Lock)
end

--- increase lock count
function Lock:lock()
  self.lockCount = self.lockCount + 1
end

local function call_listeners(lock)
  if lock.notifyPending then
    for name, fn in pairs(lock.listeners) do
      local rc, errmsg = pcall(fn, lock)
      if not rc then
        if type(errmsg) == "table" then
          errmsg = errmsg.errmsg
        end
        errmsg = tostring(errmsg)  -- just to be safe make sure it's always a string
        logger:error("error in lock '%s' listener function '%s': %s", lock.name, name, errmsg)
      end
    end
    lock.notifyPending = false
  end
end

--- decrease lock count and call listeners if it became zero and notifications
-- are pending.
function Lock:unlock()
  local count = self.lockCount - 1
  if count == 0 then
    -- became unlocked
    call_listeners(self)
  elseif count < 0 then
    count = 0
  end
  self.lockCount = count
end

--- attach a listener
-- @param [string] name, name of listener
-- @param [function] fn, listener function, if nil listener is removed
function Lock:set_listener(name, fn)
  assert(type(name) == "string", "'name' not a string")
  assert(type(fn) == "function", "'fn' not a function")
  self.listeners[name] = fn
end

--- call listeners if lock count is zero
function Lock:notify()
  self.notifyPending = true
  if self.lockCount == 0 then
    call_listeners(self)
  end
end

local M = {}

local locks = {}

-- Return a new lock with the given name.
-- If a lock with the name already exists it
-- will return that one; otherwise it creates
-- a new one.
function M.Lock(name)
  assert(type(name) == "string", "'name' not a string")
  local lock = locks[name]
  if not lock then
    lock = newLock(name)
    locks[name] = lock
  end
  return lock
end

return M