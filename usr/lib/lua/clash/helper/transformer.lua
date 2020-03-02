--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2015 - 2016  -  Technicolor Delivery Technologies, SAS **
** - All Rights Reserved                                                **
** Technicolor hereby informs you that certain portions                 **
** of this software module and/or Work are owned by Technicolor         **
** and/or its software providers.                                       **
** Distribution copying and modification of all such work are reserved  **
** to Technicolor and/or its affiliates, and are not permitted without  **
** express written authorization from Technicolor.                      **
** Technicolor is registered trademark and trade name of Technicolor,   **
** and shall not be used in any manner without express written          **
** authorization from Technicolor                                       **
*************************************************************************/
--]]

local require, setmetatable = require, setmetatable
local match = string.match

local proxy = require("datamodel-bck")

local uuid
--- Table of commands that support blacklisting.
local blacklist = {
  set = {}, -- Table of paths to blacklist for set.
  add = {}, -- Table of paths to blacklist for add.
  del = {}, -- Table of paths to blacklist for del.
}
--- Table of fault codes.
local fault = {
  INSUFFICIENT_PERMISSION = 1 -- Insufficient permission.
}

local M = {}

--- Set universally unique identifier (UUID) to use with transformer.
-- @param new_uuid UUID to use.
M.set_uuid = function(new_uuid)
  uuid = new_uuid
end

--- Set blacklist of paths for command.
-- @param command command to apply the blacklist on.
-- @param list table of paths to blacklist.
M.set_blacklist = function(command, list)
  if not blacklist[command] then
    -- No blacklist for command defined.
    return
  end
  blacklist[command] = list
end

--- Replace values of passwords with ********.
-- @param results result table of a transformer get.
-- @return table argument with password values obscured.
local function obscure_password_value(results)
  if type(results) ~= "table" then
    return results
  end

  for _,result in ipairs(results) do
    if result.type == "password" then
        result.value = "********"
    end
  end

  return results
end

--- Check if a path for a command is blacklisted.
-- @param command Use blacklist of command.
-- @param path path to validate against blacklist.
-- @return true if authorized, false otherwise.
local function authorize_path(command, path)
  local list = blacklist[command] or {}
  for _,pattern in ipairs(list) do
    if match(path, pattern) then
      return false
    end
  end
  return true
end

--- Handler, transformer get commands first pass through this handler.
-- Obscures any password values from datamodel location(s).
local function get(uuid, ...)
  results, errmsg, errcode = proxy.get(uuid, ...)
  results = obscure_password_value(results)
  return results, errmsg, errcode
end

--- Handler, transformer set commands first pass through this handler.
-- Checks for blacklisted paths.
local function set(uuid, ...)
  local args = {...}
  local arg1 = args[1]
  local arg2 = args[2]
  -- if 'arg2' is present assume the caller passed a path and value string
  if arg2 then
    if type(arg1) == "string" and not authorize_path("set", arg1) then
      return nil, { { path = arg1, errcode = fault.INSUFFICIENT_PERMISSION, errmsg = "insufficient permission" } }
    end
  else -- otherwise assume 'arg1' is a table of (path, value) pairs
    if type(arg1) == "table" then
      for path, value in pairs(arg1) do
        -- if one path is unauthorized, deny setting all paths
        if type(path) == "string" and not authorize_path("set", path) then
          return nil, { { path = path, errcode = fault.INSUFFICIENT_PERMISSION, errmsg = "insufficient permission" } }
        end
      end
    end
  end
  return proxy.set(uuid, ...)
end

--- Handler, transformer add commands first pass through this handler.
-- Checks for blacklisted paths.
local function add(uuid, path, name)
  if type(path) == "string" and not authorize_path("add", path) then
    return nil, "insufficient permission", fault.INSUFFICIENT_PERMISSION
  end
  return proxy.add(uuid, path, name)
end

--- Handler, transformer del commands first pass through this handler.
-- Checks for blacklisted paths.
local function del(uuid, path)
  if type(path) == "string" and not authorize_path("del", path) then
    return nil, "insufficient permission", fault.INSUFFICIENT_PERMISSION
  end
  return proxy.del(uuid, path)
end

--- Table and metatable of handlers for transformer commands.
-- Transformer commands which have a handler specified, first pass through this
-- handler. If no handler, the command is directly passed to transformer.
local handlers = {
  get = get,
  set = set,
  add = add,
  del = del,
  __index = function(table, key)
    return proxy[key]
  end
}
setmetatable(handlers, handlers)

setmetatable(M, {
  __index = function(tbl, key)
    local handler = handlers[key]
    return function(...)
      return handler(uuid, ...)
    end
  end,
})

return M
