--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

---
-- An event source implementation for ubus.
--
-- Use it in for example your `add_watchers()` mapping API implementation
-- so you are notified about changes on ubus and need to, in turn, tell
-- Transformer about changes in your part of the datamodel.
-- For more information see `./doc/skeleton.map` and './doc/eventing.md'.
-- @module transformer.eventsource.ubus
-- @usage
-- local function ubus_event_cb(mapping, event, data)
--   if data.state then
--     return { { key = data["mac-address"], paramname = "Active" } }
--   end
-- end
-- mapping.add_watchers = function()
--   local ubus_evsrc = eventsource("ubus")
--   ubus_evsrc.watch_event(mapping, ubus_event_cb, "hostmanager.device")
-- end

local pairs, ipairs, pcall, type, error = pairs, ipairs, pcall, type, error
local format = string.format

local resolve = require("transformer.xref").resolve
local logger = require("tch.logger")
local trlock = require("transformer.lock").Lock("transformer")
local ubus = require("transformer.mapper.ubus").connect()

local store

-- All the registered event watches.
-- For each ubus event path we keep a table that maps
-- the mapping that put watch in polace to the callback.
-- Note that this means a given mapping can only register
-- one callback for a particular ubuss event.
local event_watches = {}

-- Whenever a ubus event comes in we don't process it immediately
-- but put it in a queue. The reason is that an event might come in
-- while a mapping is doing ubus calls and we don't want to recursively
-- start handling this. Only at the top level event loop should we
-- process things.
local eventQueue = {}

local function process_single_event(ubus_event, data)
  local watches = event_watches[ubus_event]
  -- Let's play safe although it shouldn't be possible because
  -- we can only receive an event because we listened for it
  -- and that can only happen if a watch was added.
  if not watches then
    return 0
  end

  local nEvents = 0
  for mapping, cb in pairs(watches) do
    local rc, ret = pcall(cb, mapping, ubus_event, data)
    if not rc then
      logger:error("error in event watch callback by %s on %s: %s",
                   mapping.objectType.name, ubus_event, ret)
    elseif ret then
      for _, info in ipairs(ret) do
        -- Sanity check: if paramname is returned by cb, check it actually exists in parameters list.
        if info.paramname and not mapping.objectType.parameters[info.paramname] then
          logger:debug("[UBUS_source] Ignoring event for unknown parameter %s on typepath %s", info.paramname, mapping.objectType.name)
        else
          local path = resolve(store, mapping.objectType.name, info.key, true)
          if path then
            path = path .. "."
            if info.paramname then
              path = path .. info.paramname
            end
            logger:debug("[UBUS_source] queueing event(%s, %s, %s, %s)", info.action or "set", mapping.objectType.name, info.key, path)
            store.eventhor:queueEvent(nil, mapping, path, info.action or "set")
            nEvents = nEvents + 1
          end
        end
      end
    end
  end
  return nEvents
end

local function process_event_queue()
  logger:debug("processing event queue %d", #eventQueue)
  local nEvents = 0
  for _, ev in ipairs(eventQueue) do
    nEvents = nEvents + process_single_event(ev[1], ev[2])
  end
  if nEvents > 0 then
    store.eventhor:fireEvents()
  end
  eventQueue = {}
end
trlock:set_listener("ubus_eventsource", process_event_queue)

local M = {}

--- Add a watch for a certain ubus event together with a callback
-- to invoke when the event occurs.
-- @tparam table mapping The mapping who is putting the watch in place.
-- @tparam function cb The callback to invoke when the event occurs.
--
--   The callback should return quickly and not do lots of processing
--   and checks (e.g. UCI or ubus accesses). It's better to return an
--   event that is later dropped by Transformer than to desperately try
--   to only send an event when really needed.
--
--   In case a mapping has already registered a callback for a given ubus
--   event and it tries to register a different callback then this will
--   overwrite the old callback.
--
--   For each matching ubus event it will be invoked with the following arguments:
--
--   - The mapping who initially created the watch.
--   - A string describing the ubus event.
--   - A table with the ubus event data.
--
--   The callback must return nothing or false when the change isn't relevant
--   and shouldn't be evented. If it is relevant then the callback must return
--   an array of tables with the following fields:
--
--   - `key`: The key of the rightmost multi instance objecttype in the mapping's
--      typepath for which an event needs to be sent. In case there is no
--      multi instance objecttype then an empty string must be used.
--   - `paramname`: The name of the datamodel parameter for which an event needs
--      to be sent. Only relevant on a "set" action.
--   - `action`: Optionally you can send an event with a different action than
--      the default one, which is a "set". This way a ubus event can be used
--      to for example signal that a new object instance appeared.
--
--    **NOTE: at this moment only the "set" action is supported.**
-- @tparam string ubus_event The ubus event identifier to watch out for.
function M.watch_event(mapping, cb, ubus_event)
  if type(mapping) ~= "table" or not mapping.objectType then
    error("invalid mapping passed", 2)
  end
  if type(cb) ~= "function" then
    error("callback not a function", 2)
  end
  if type(ubus_event) ~= "string" or ubus_event == "" then
    error("invalid ubus event identifier", 2)
  end
  local watch = event_watches[ubus_event]
  if not watch then
    -- for each ubus event we only listen once and multiplex
    -- an event to all the watchers
    watch = {}
    event_watches[ubus_event] = watch
    -- when ubus invokes our callback it doesn't tell us for which
    -- event so we can't use a generic callback and instead have to
    -- generate a callback closure for each event
    ubus:listen({ [ubus_event] = function(data)
      eventQueue[#eventQueue + 1] = { ubus_event, data }
      trlock:notify()
    end })
  end
  -- sanity check: is there already a callback for this event and mapping?
  local current_cb = watch[mapping]
  if current_cb and current_cb ~= cb then
    logger:warning("overwriting callback for event %s and mapping %s",
                   ubus_event, mapping.objectType.name)
  end
  watch[mapping] = cb
end

function M.set_store(s)
  store = s
end

return M
