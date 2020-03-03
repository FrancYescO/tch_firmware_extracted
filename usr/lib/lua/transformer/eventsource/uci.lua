--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

---
-- An event source implementation for UCI.
--
-- Use it in for example your `add_watchers()` mapping API implementation
-- so you are notified about changes on UCI and need to, in turn, tell
-- Transformer about changes in your part of the datamodel.
-- For more information see `./doc/skeleton.map` and './doc/eventing.md'.
-- @module transformer.eventsource.uci
-- @usage
-- local function watch_cb(mapping, action, config, sectiontype, sectionname, option)
--   return { { key = sectionname, paramname = "SSID" } }
-- end
-- mapping.add_watchers = function()
--   local uci_evsrc = eventsource("uci")
--   uci_evsrc.watch(mapping, { set = watch_cb }, "wireless", "wifi-iface", nil, "ssid")
-- end
local getmetatable, select, pairs, ipairs, type, error, pcall =
      getmetatable, select, pairs, ipairs, type, error, pcall
local format = string.format

local resolve = require("transformer.xref").resolve
local logger = require("tch.logger")

-- Array of all registered watches, grouped per config.
-- Since config is mandatory we can group them so we don't need
-- to do a linear scan of all watches when we're matching.
local watches = {}

local store

-- TODO: pass section type
local function check_watches(action, config, sectionname, option)
  logger:debug("checking watches for %s on %s.%s.%s", action, config, sectionname, option)
  local group = watches[config]
  if not group then
    return
  end
  -- Collect the callbacks.
  -- We only call a specific callback once per mapping. This is to avoid
  -- duplicate events when a mapping uses overlapping watches with
  -- the same callback.
  -- The idea is that for a given change on UCI a particular callback is
  -- never called more than once with the same arguments.
  local callbacks = {}
  for _, watch in ipairs(group) do
    if (not watch.sectionname or watch.sectionname == sectionname) and
       (not watch.option or watch.option == option) then
      local cb = watch[action]
      if cb then
        -- for each matching watch put it in the 'callbacks' table
        -- if it's not already there
        local mapping = watch.mapping
        local cb_mappings = callbacks[cb]
        if not cb_mappings then
          cb_mappings = {}
          callbacks[cb] = cb_mappings
        end
        if not cb_mappings[mapping] then
          logger:debug("storing callback for %s", mapping.objectType.name)
          cb_mappings[mapping] = true
        end
      end
    end
  end
  -- Now invoke all the collected callbacks.
  for cb, mappings in pairs(callbacks) do
    for mapping in pairs(mappings) do
      -- TODO: we could also pass the new value in case of a "set"
      local rc, ret = pcall(cb, mapping, action, config, "?", sectionname, option)
      if not rc then
        logger:error("watch callback by %s on %s of %s.?.%s.%s: %s", mapping.objectType.name,
                     action, config, sectionname, option, ret)
      elseif ret then
        for _, info in ipairs(ret) do
          -- Sanity check: if paramname is returned by cb, check it actually exists in parameters list.
          if info.paramname and not mapping.objectType.parameters[info.paramname] then
            logger:debug("[UCI_source] Ignoring event for unknown parameter %s on typepath %s", info.paramname, mapping.objectType.name)
          else
            -- TODO: should we allow a 'typepath' field so mapping can send an event for a
            --       different type than the one of the mapping associated with the watch?
            -- TODO optimize call to resolve (one of the first thing it does, is look for mapping. Can it not simple be passed?)
            local path = resolve(store, mapping.objectType.name, info.key, true)
            if path then
              path = path .. "."
              if info.paramname then
                path = path .. info.paramname
              end
              logger:debug("[UCI_source] queueing event(%s, %s, %s, %s)", info.action or action, mapping.objectType.name, info.key, path)
              store.eventhor:queueEvent(nil, mapping, path, info.action or action)
            end
          end
        end
      end
    end
  end
end

-- On load we patch the __index table containing the methods on
-- a UCI cursor so that for certain operations a wrapper function
-- is called. That way we see what changes are being made on UCI
-- and can check these against the watches.
-- Note that this implementation makes some assumptions:
-- - All cursor objects share the same __index and __index is a table.
-- - Nobody takes a local reference to the methods we wrap.
-- This implementation has the benefit that there's only an indirection
-- for the methods we need to monitor; all other code paths remain as
-- before. It also works for cursors that have been created before
-- we were loaded so we can be lazily loaded.
do
  local uci = require("uci")

  local set  -- original set() method
  local function set_wrapper(cursor, ...)
    logger:debug("set_wrapper called")
    -- TODO: should we first call the original set and only
    --       do check_watches() if it is successful?
    local nargs = select("#", ...)
    if nargs == 1 then
      -- cursor:set(assignment)
      logger:warning("set_wrapper with 1 args not supported")
    elseif nargs == 3 then
      -- cursor:set(config, sectionname, sectiontype)
      logger:warning("set_wrapper with 3 args not supported")
    elseif nargs == 4 then
      -- cursor:set(config, sectionname, option, value)
      check_watches("set", ...)
    end
    return set(cursor, ...)
  end

  -- Create a cursor so we can get to the __index table.
  local cursor = uci.cursor()
  local __index = getmetatable(cursor).__index
  -- Store the original method and replace it with our wrapper.
  set = __index.set
  __index.set = set_wrapper
  cursor:close()
end

local M = {}

--- Add a watch for changes to certain UCI fields together with callbacks to
-- invoke when changes happen.
-- @tparam table mapping The mapping who is putting the watch in place.
-- @tparam table actions A map between a certain action ("set", "add", "del") and
--   a callback to invoke. The callback should return quickly and not do lots
--   of processing and checks (e.g. UCI or ubus accesses). It's better to return
--   an event that is later dropped by Transformer than to desperately try to
--   only send an event when really needed.
--
--   For each change on UCI the callback will be called with the following
--   arguments, but only once for a particular mapping (i.e. for a certain
--   change on UCI a particular callback is never called more than once with
--   the same arguments):
--
--   - The mapping who initially created the watch.
--   - The action that was done on UCI; one of "set", "add" or "del".
--   - The UCI config on which the change occurred.
--   - The UCI section type on which the change occurred.
--   - The UCI section name on which the change occurred.
--   - The UCI option on which the change occurred, if applicable.
--
--   **NOTE: at this moment only the "set" action is (partially) implemented
--   and as section type always the string "?" is passed to the callback.**
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
--      the one with which the callback is invoked. For instance this allows
--      you to turn a "set" on a list option in UCI into a "add" event.
-- @string config The UCI config to watch.
-- @string[opt] sectiontype The UCI section type to watch. If all section types
--   in the config need to be watched then omit this parameter or pass nil.
--   **NOTE: this is currently ignored.**
-- @string[opt] sectionname The UCI section name to watch. If all section
--   names in the config or section type need to be watched then omit this
--   parameter or pass nil.
-- @string[opt] option The UCI option to watch. If all options in the
--   config, section type or section name need to be watched then omit this
--   parameter or pass nil.
function M.watch(mapping, actions, config, sectiontype, sectionname, option)
  if type(mapping) ~= "table" or not mapping.objectType then
    error("invalid mapping passed", 2)
  end
  -- 'actions' should contain functions as values
  for action, cb in pairs(actions) do
    if type(cb) ~= "function" then
      error(format("'%s' callback not a function", action), 2)
    end
  end
  -- 'config' is mandatory; you shouldn't be watching entire UCI
  if not config or config == "" then
    error("UCI config name must be provided", 2)
  end
  -- store the watch
  logger:debug("adding watch for %s.%s.%s.%s", config, tostring(sectiontype), tostring(sectionname), tostring(option))
  -- Explicitly unpack the 'actions' instead of storing it as separate table.
  -- Storing a separate table would make our watch have 5 fields while unpacking makes
  -- it have at most 7 fields. Tables grow with powers of 2 so 5 or 7 fields makes no real
  -- difference while saving the overhead of the separate table and extra level of indirection.
  local group = watches[config]
  if not group then
    group = {}
    watches[config] = group
  end
  group[#group + 1] = { mapping = mapping, sectiontype = sectiontype, sectionname = sectionname,
                        option = option, set = actions.set, add = actions.add, del = actions.del }
end

-- TODO: Ugh, the store is needed to do resolving in check_watches()
--       but isn't there a better way to get a hold of it?
--       Perhaps we should make all Transformer modules singletons
--       instead of having some of them singleton and some return
--       some kind of context with methods...
function M.set_store(s)
  store = s
end

return M
