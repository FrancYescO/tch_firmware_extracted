--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

--- Helper module to handle path manipulation.
-- This module groups all functions related to path processing.
local match, gsub, sub, find = string.match, string.gsub, string.sub, string.find
local insert = table.insert

-- The placeholder that indicates transformer needs to operate on it.
local transformer_placeholder = "{i}"
-- The placeholder that indicates transformer needs to operate on it and treat it as an alias.
local transformer_alias_placeholder = "["
-- The placeholder that indicates transformer should not touch it.
local passthrough_placeholder = "@"

local PathFinder = {}

--- Split off the last part of a partial type path.
-- @param #string typepath A type path in the tree. This should end in a dot.
-- @return #string, #string Both parts of the type path after the split. The first return
--                          value contains the first part of the path and the second return
--                          value contains the last part. If one or both parts don't exist,
--                          they are replaced by empty strings.
local function stripEnd(typepath)
  local lStart, lEnd = typepath:find("[^%.]*%.$")
  if lStart and lStart >= 1 then
    return typepath:sub(1, lStart-1), typepath:sub(lStart, lEnd)
  end
  return "",""
end

--- Split off the last part of a partial type path and remove any trailing dot.
-- @param #string typepath A type path in the tree. This should end in a dot.
-- @return #string, #string Both parts of the type path after the split. The first return
--                          value contains the first part of the path and the second return
--                          value contains the last part. If the last part had a trailing dot
--                          (which it should have), this is removed. If one or both parts
--                          don't exist, they are replaced by empty strings.
local function stripEndNoTrailingDot(typepath)
  local first,last = stripEnd(typepath)
  if #last > 0 and last:sub(#last,#last)=="." then
    last = last:sub(1,#last-1)
  end
  return first,last
end

--- Check if the given placeholder indicates if it needs to be handled by
-- transformer or not.
-- @param #string placeHolder The placeholder we need to check.
-- @return #boolean True if the placeholder equals the transformer placeholder,
--                  false otherwise.
function PathFinder.isTransformed(placeHolder)
  return placeHolder == transformer_placeholder
end

--- Check if the given placeholder indicates if it is pass-through
-- or not
-- @param #string placeHolder The placeholder we need to check.
-- @return #boolean True if the placeholder equals the pass-through placeholder,
--                  false otherwise.
function PathFinder.isPassThrough(placeHolder)
  return placeHolder == passthrough_placeholder
end

--- Check if the given placeholder indicates a multi-instance type.
-- @param #string placeHolder The placeholder we need to check.
-- @return #boolean True if the placeholder indicates a multi-instance type,
--                  false otherwise.
function PathFinder.isMultiInstance(placeHolder)
  --return isTransformed(placeHolder) or isPassThrough(placeHolder)
  return (placeHolder == transformer_placeholder) or (placeHolder == passthrough_placeholder)
end

--- Check if the given type path ends with a placeholder or not.
-- @param #string typepath The type path we need to check.
-- @return #boolean True if the given type path ends with a placeholder,
--                  false otherwise.
function PathFinder.endsWithPlaceholder(typepath)
  local _,placeHolder = PathFinder.stripEndNoTrailingDot(typepath)
  --return isMultiInstance(placeHolder)
  return (placeHolder == transformer_placeholder) or (placeHolder == passthrough_placeholder)
end

local endsWithPassThroughPattern = "%."..passthrough_placeholder.."%.$"

--- Check if the given type path ends with a pass-through placeholder
-- or not.
-- @param #string typepath The type path we need to check.
-- @return #boolean True if the given type path ends with a pass-through
--                  placeholder, false otherwise.
function PathFinder.endsWithPassThroughPlaceholder(typepath)
  return (find(typepath, endsWithPassThroughPattern) ~= nil)
end

--- Returns the partial path and optional parameter from the given path.
-- @param #string path The path that needs to be split in partial path and parameter.
-- @return #string, #string If the given path was a complete path the first argument contains
--                          the partial path and the second argument contains the parameter.
-- @return #string, #string If the given path was a partial path the first argument contains
--                       this partial path and the second argument is the empty string.
-- @return #nil, #nil If the given path wasn't a valid path, both return values are nil.
function PathFinder.divideInPathParam(path)
  return match(path, "(.*%.)([^%.]*)$")
end

-- Local array of instance references. Used in iref_parse and iref_sub.
-- These functions only work correctly if this variable is initialized correctly.
local irefs = {}
-- Local array of aliases. Used in iref_parse and iref_sub.
-- These functions only work correctly if this variable is initialized correctly.
local aliases = {}
local no_alias = ""

--- Method used to parse object path fragments.
-- If the fragment indicates it's a pass-through or a transformer part,
-- it will be replaced by the correct placeholder.
-- @param #string part The fragment we need to inspect.
-- @return #string A placeholder if the fragment requires it, otherwise the
--                 fragment itself is returned.
local function iref_parse(part)
  --if isPassThrough(sub(part,1,1)) then
  if sub(part,1,1) == passthrough_placeholder then
    insert(irefs, 1, sub(part,2))
    -- Insert dummy alias to keep the array in line with irefs.
    insert(aliases, 1, no_alias)
    return passthrough_placeholder
  elseif sub(part,1,1) == transformer_alias_placeholder then
    -- Since we don't know the real ireference, insert alias to keep
    -- the array in line with aliases.
    insert(irefs, 1, sub(part,2, #part-1))
    insert(aliases, 1, irefs[1])
    return transformer_placeholder
  elseif match(part,"^%d+$") then
    insert(irefs, 1, part)
    -- Insert dummy alias to keep the array in line with irefs.
    insert(aliases, 1, no_alias)
    return transformer_placeholder
  end
  return part
end

--- Get the type path for a given object path.
-- @param #string objectpath The given object path.
-- @return #string, #table, #table The type path (ie all instance numbers/names/aliases
--                         are replaced with {i}/@) is returned as first
--                         argument, the corresponding instance references
--                         as second argument and the corresponding aliases as third
--                         argument. The instance references array will also contain the
--                         aliases if present.
function PathFinder.objectPathToTypepath(objectpath)
  irefs = {}
  aliases = {}
  -- Parse out the instance references from the path.
  local typepath = gsub(objectpath, "([^%.]+)", iref_parse)
  return typepath, irefs, aliases
end

local count

--- Method used to parse type path fragments.
-- If the fragment indicates it's a pass-through or a transformer placeholder,
-- it will be replaced by the corresponding instance reference or alias.
-- @param #string part The fragment we need to inspect.
-- @return #string An instance reference or alias if the fragment requires it, otherwise the
--                 fragment itself is returned.
local function iref_sub(part)
  --if PathFinder.isMultiInstance(part) then
  if (part == transformer_placeholder) or (part == passthrough_placeholder) then
    if aliases[count] and aliases[count] ~= no_alias then
      local alias = aliases[count]
      alias = transformer_alias_placeholder .. alias .. "]"
      count = count - 1
      return alias
    else
      local iref = irefs[count]
      if part == passthrough_placeholder then
        iref = passthrough_placeholder..iref
      end
      count = count - 1
      return iref
    end
  end
  return part
end

--- Replace placeholders with real instance references or aliases,
-- transforming a type path into a object path.
-- @param #string typepath The path of the object (with placeholders)
-- @param #table ireferences The array of instance references.
-- @param #table alias The optional array of aliases. These will get precedence over instance references.
-- @return #string The type path with all placeholders replaced by the given references and aliases.
-- Note: the length of the irefs array must equal the number of placeholders
--   in typepath.
function PathFinder.typePathToObjPath(typepath, ireferences, alias)
  irefs = ireferences
  aliases = alias or {}
  count = #irefs
  return gsub(typepath, "([^%.]+)", iref_sub)
end

PathFinder.transformer_placeholder = transformer_placeholder
PathFinder.passthrough_placeholder = passthrough_placeholder
PathFinder.stripEndNoTrailingDot = stripEndNoTrailingDot
PathFinder.stripEnd = stripEnd

return PathFinder