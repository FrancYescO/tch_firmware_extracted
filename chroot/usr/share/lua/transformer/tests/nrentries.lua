--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local print = print
local format = string.format

require 'lunit'
module(... or 'nrentries', lunit.testcase, package.seeall)

local DEBUG=false

local function printf(fmt, ...)
  if DEBUG then
    print(format(fmt, ...))
  end
end

local proxy = require 'datamodel-bck'
local unix = require 'tch.socket.unix'
local msg = require('transformer.msg').new()

local subscriptions = {}
local uuid

local function new_uuid()
  local uuid
  local fd = io.open("/proc/sys/kernel/random/uuid", "r")
  if fd then
    uuid = fd:read('*l')
    uuid = string.gsub(uuid,"-","")
    fd:close()
  end
  return uuid
end

local SUBTYPE_UPDATE = 1
local SUBTYPE_ADD = 2
local SUBTYPE_DEL = 3

local function get_value(uuid, path, display)
  display = (display==nil) and true or display
  local values, err = proxy.get(uuid, path)
  if not values then
    printf("error retrieving value of %s: %s", path, err)
    return
  end
  for _, entry in ipairs(values) do
    if display then
      printf("%s%s : %s = '%s'",
              entry.path,
              entry.param,
              entry.type,
              entry.value)
    end
  end
  if #values==1 then
    return values[1].value
  else
    return ""
  end
end

local function subscribe(uuid, path, subtype, options)
  options = options or 0
  local sk = unix.dgram(unix.SOCK_CLOEXEC)
  local address = 'listener-'..uuid
  local ok, err = sk:bind(address)
  if not ok then
    return nil, err
  end
  local id, nonevented = proxy.subscribe(uuid, path, address, subtype, options)
  if not id then
    return nil, nonevented
  end
  sub = {
    uuid = uuid;
    listener = sk;
    id = id;
    nonevented = nonevented;
  }
  subscriptions[#subscriptions+1] = sub
  return sub
end

local function receive_event(subscription)
  local events = {}
  local is_last = false
  while not is_last do
    local data, from = subscription.listener:recvfrom()
    if not data then
      printf("error while receiving: %s", from)
      return
    end
    local tag
    local uuid
    tag, is_last, uuid = msg:init_decode(data)
    if tag==msg.tags.EVENT then
      local event = msg:decode()
      printf("EVENT subscription=%d, path=%s, event=%d",
                event.id,
                event.path,
                event.eventmask)
      if event.eventmask==SUBTYPE_UPDATE then
        get_value(subscription.uuid, event.path)
      end
      events[#events+1] = event
    end
  end
  return events
end

local function unsubscribe_all(subscriptions)
  for _, sub in ipairs(subscriptions) do
    -- no unsubscribe available yet
  end

end


function setup()
  local err
  uuid = uuid or new_uuid()
  subscriptions = {}
end

function teardown()
  unsubscribe_all(subscriptions)
  subscriptions = {}
end

function test_adddel_nrentries_event()
  local path = "Users.UserNumberOfEntries"
  local numUsers = tonumber(get_value(uuid, path))
  assert(numUsers)
  local sub, err = subscribe(uuid, path, SUBTYPE_UPDATE)
  assert_not_nil(sub, err)
  
  local err
  local newid
  local events
  local newval
  
  -- add a new user
  newid, err = proxy.add(uuid, "Users.User.")
  assert_not_nil(newid, err)
  
  -- receive the event
  events =  receive_event(sub)
  assert_not_nil(events)
  assert_equal(1, #events)
  assert_equal(path, events[1].path)
  
  -- verify the number of entries increased with 1
  newval = tonumber(get_value(uuid, path, false))
  assert_equal(numUsers+1, newval)
  
  -- delete the user 
  local deleted
  deleted, err = proxy.del(uuid, format("Users.User.%d.", newid))
  assert_true(deleted, err)
  
  -- receive the event
  events =  receive_event(sub)
  assert_not_nil(events)
  assert_equal(1, #events)
  assert_equal(path, events[1].path)

  -- verify number of entries decreased again
  newval = tonumber(get_value(uuid, path, false))
  assert_not_nil(newval)
  assert_equal(numUsers, newval)
end

