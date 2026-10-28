
local type = type
local setmetatable = setmetatable
local ipairs = ipairs

local nav = require 'transformer.navigation'

local M = {}

local function make_unique(alias, alias_db_list)
  local aliases = {}
  for _, entry in ipairs(alias_db_list) do
    aliases[entry.alias] = true
  end
  if aliases[alias] then
    -- alias was not unique, start appending numbers
    local guess
    local n=0
    repeat
      n = n+1
      guess = alias..n
    until not aliases[guess]
    alias = guess
  end
  return alias
end

local function do_get(db, mapping, param, key, ...)
  local info = db:getAlias(mapping.tp_id, key)
  -- info will never be nil as the object with the given key must exist
  -- (if it didn't exist, this get function would not be called)
  local alias = info.alias
  if not alias then
    local aliases = db:getAliases(mapping.tp_id, info.parent)

    -- create an initial alias value
    local base
    if mapping.aliasDefault then
      base = nav.get_parameter_value(mapping, mapping.aliasDefault, key, ...) or base
    else
      local name = mapping.objectType.name:gsub("%.{i}%.$", "."):match("([^%.]+)%.$") or ""
      local index = info.ireferences:match("^(%d+)") or ""
      base = name.."-"..index
    end
    alias = make_unique("cpe-"..base, aliases)
    db:setAlias(info.id, alias)
  end
  return alias
end

local function do_set(db, mapping, param, value, key)
  local info = db:getAlias(mapping.tp_id, key)
  if value ~= info.alias then
    if value:match("^%a[%a%d_-]*$") and (#value<=64) then
      if not db:setAlias(info.id, value) then
          return nil, "alias value is not unique"
      end
    else
      return nil, "value is invalid"
    end
  end
end

local function do_accessors(mapping, get, set)
  local paramName = mapping.objectType.aliasParameter
  if paramName and mapping.objectType.parameters[paramName] then
    return get, set
  end
end

function M.new(store)
  local get = function(...)
    return do_get(store.persistency._db, ...)
  end
  local set = function(...)
    return do_set(store.persistency._db, ...)
  end

  return {
    accessors = function(mapping)
      return do_accessors(mapping, get, set)
    end
  }
end

return M
