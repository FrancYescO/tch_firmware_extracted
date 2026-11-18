--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local setmetatable, require, ipairs, pairs, pcall, tostring = setmetatable, require, ipairs, pairs, pcall, tostring
local floor = math.floor

local pathFinder = require("transformer.pathfinder")
local fault = require("transformer.fault")
local uds = require("tch.socket.unix")
local max_size = uds.MAX_DGRAM_SIZE
local msg = require("transformer.msg").new()
local tags = msg.tags
local logger = require("tch.logger")
local bit = require("bit")

local objectPathToTypepath,            divideInPathParam =
      pathFinder.objectPathToTypepath, pathFinder.divideInPathParam

-- Methods available on an Eventhor.
local Eventhor = {}
Eventhor.__index = Eventhor

local mt = {}

mt.__index = function(table, key)
  local sk, errmsg = uds.dgram(bit.bor(uds.SOCK_NONBLOCK, uds.SOCK_CLOEXEC))
  if not sk then
    if errmsg then
      logger:error("failed to create event send socket: %s", tostring(errmsg))
    end
    return
  end
  local rc
  rc, errmsg = sk:connect(key)
  if rc then
    table[key] = sk
    return sk
  end
  if errmsg then
    logger:error("failed to connect event send socket: %s", tostring(errmsg))
  end
end

local sockets = setmetatable({},mt)

local function type_mask2table(mask)
  local subscr_type = {
    set = (mask % 2) == 1,
    add = (floor(mask / 2) % 2) == 1,
    delete = (floor(mask / 4) % 2) == 1,
  }
  return subscr_type
end

local function type_2mask(subscr_type)
  local mask = {
    set = 1,
    add = 2,
    delete = 4,
    all = 7,
  }
  return mask[subscr_type] or 0
end

local option_no_own_events = 1
local function check_option(mask, option)
  return floor(mask / option) % 2 == 1
end

--- Load the watchers.
local function beginWatch(self)
  -- We add the watchers of all the mappings, but this could be optimized
  -- to only start watching based on the datamodel root of the subscription.
  for _, mapping in ipairs(self.store.mappings) do
    if mapping.add_watchers then
      local rc, errmsg = pcall(mapping.add_watchers, mapping)
      if not rc then
        logger:warning("add_watchers() on mapping %s threw an error :%s", mapping.objectType.name, errmsg)
      end
      mapping.add_watchers = nil
    end
  end
  -- Now my watch begins. It shall not end until my death.
end

--- Retrieve canDeny parameters below the given instance path.
local function getCanDenies(self, uuid, path)
  local non_evented_expanded = {}
  for obj in self.store:navigate(uuid, path, "get") do
    for param in obj:params() do
      if param:isCanDeny() then
        local path, prm = param:getName()
        non_evented_expanded[#non_evented_expanded + 1] = path .. prm
      end
    end
  end
  return non_evented_expanded
end

function Eventhor:addSubscription(uuid, path, addr, subscr_mask, options)
  -- Some sanity checks
  if not path or not addr or not subscr_mask or not options then
    fault.InternalError("Incorrect number of arguments for subscription.")
  end
  -- Verify we have a mapping for the path.
  local objpath, param = divideInPathParam(path)
  local typepath = objectPathToTypepath(objpath)
  local mapping = self.store:get_mapping_incomplete(typepath)
  if not mapping or (param ~= "" and not self.store:mappingContainsParameter(mapping, param)) then
    fault.InvalidName("Invalid path %s", path)
  end
  local sublist = self.subscriptionlist
  -- Let the mappings add their event source watches lazily, when the
  -- first valid subscription is received.
  if self.subscriptions_counter == 0 then
    beginWatch(self)
    beginWatch = nil
  end
  self.subscriptions_counter = self.subscriptions_counter + 1
  local subscriptionID = self.subscriptions_counter

  -- Create the actual subscription.
  local sub = {
    ID = subscriptionID,
    path = path,
    type = type_mask2table(subscr_mask),
    options = options,
    uuid = uuid,
    addr = addr,
    mapping = mapping,
  }

  -- Add the subscription to the subscriptions list.
  sublist[subscriptionID] = sub

  -- Add the subscription to the mapping.
  if not mapping.subscriptions then
    mapping.subscriptions = {}
  end
  local subscriptions = mapping.subscriptions
  subscriptions[subscriptionID] = sub

  -- 'path' can be a future path, which will cause navigate to fail. Catch the error.
  local rc, non_evented_expanded = pcall(getCanDenies, self, uuid, path)

  -- If the pcall failed, 'non_evented_expanded' will contain the error code. Drop this information.
  if not rc then
    non_evented_expanded = nil
  end

  return subscriptionID, non_evented_expanded
end

function Eventhor:removeSubscription(uuid, subscriptionID)
  local sublist = self.subscriptionlist
  local subscription = sublist[subscriptionID]
  if not subscription then
    fault.InvalidName("Invalid subscription id %s", subscriptionID)
  end
  --Check uuid
  if subscription.uuid ~= uuid then
    fault.RequestDenied("Remove subscription id %s not allowed", subscriptionID)
  end
  --Remove the subscription from the mapping
  local subscriptions = subscription.mapping.subscriptions
  if subscriptions then
    subscriptions[subscriptionID] = nil
  end
  --Invalidate sublist entry
  sublist[subscriptionID] = nil
  return true
end

local function queue_single_event(self, uuid, mappings, path, operation)
  uuid = uuid or self.store:clientUUID()
  local event_queue = self.event_queue
  for _, mapping in ipairs(mappings) do
    local subscriptions = mapping.subscriptions
    if subscriptions then
      for id, sub in pairs(subscriptions) do
        logger:debug("    subscription on %s", sub.path)
        if path:match("^"..sub.path) and sub.type[operation] then
          if (check_option(sub.options, option_no_own_events) and uuid == sub.uuid) then
            logger:debug("suppressing event (%d) with op %s from %s (path=%s) for uuid %s", id, operation, sub.path, path, sub.uuid)
          else
            -- Note that we don't check that an event is already in the queue.
            -- In theory it's possible that one request contains multiple sets and
            -- several of those sets trigger the same event.
            logger:debug("queuing event for subscription (%d) with op %s from %s (path=%s) for uuid %s", id, operation, sub.path, path, sub.uuid)
            event_queue[#event_queue + 1] = { id = id, path = path, operation = operation}
          end
        end
      end
    end
  end
end

function Eventhor:queueEvent(uuid, mapping, path, operation)
  local allMappings = self.store:ancestors(mapping)
  queue_single_event(self, uuid, allMappings, path, operation)
end

local known_ops = {"set","add","delete"}
function Eventhor:queueEvents(uuid, mapping, operations)
  local allMappings = self.store:ancestors(mapping)
  for i = 1, #known_ops do
    local op = known_ops[i]
    local ops = operations[op]
    if ops then
      for _,path in ipairs(ops) do
        queue_single_event(self, uuid, allMappings, path, op)
      end
    else
      logger:debug("op %s not found in operations", op)
    end
  end
end

local function fire_event(self, subscr_id, path, event_type)
  local address = self.subscriptionlist[subscr_id].addr
  local sk = sockets[address]
  if not sk then
    -- Socket creation failed. Drop event or retry?
    return
  end
  msg:init_encode(tags.EVENT, max_size)
  msg:encode(subscr_id, path, type_2mask(event_type), "0")
  msg:mark_last()
  local rc, errmsg = sk:send(msg:retrieve_data())
  if not rc then
    sk:close()
    sockets[address] = nil
    if errmsg then
      logger:error("failed to send event: %s", errmsg)
    end
  end
end

function Eventhor:fireEvents()
  for _, event in pairs(self.event_queue) do
    logger:debug("firing event (%d) with op %s from %s", event.id, event.operation, event.path)
    fire_event(self, event.id, event.path, event.operation)
  end
  self.event_queue = {}
end

function Eventhor:dropEvents()
  self.event_queue = {}
end

local M = {
  new = function(store)
    local self = {
      store = store,
      subscriptionlist = {},
      subscriptions_counter = 0,
      event_queue = {},
    }
    store:registerEventhor(self)
    return setmetatable(self, Eventhor)
  end
}

return M
