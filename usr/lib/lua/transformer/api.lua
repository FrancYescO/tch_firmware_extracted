--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local require, pcall, tostring, setmetatable, type, ipairs =
      require, pcall, tostring, setmetatable, type, ipairs

local fault = require 'transformer.fault'
local xref = require 'transformer.xref'

-- Methods available on a Transformer context.
local Transformer = {}
Transformer.__index = Transformer

--- Close down a Transformer context.
-- It can not be used anymore after this method has been called.
function Transformer:close()
    self.store:close()
    self.store = nil
end

--- Wrapper function around pcall.
-- If the function that was pcalled returns an error, the error is
-- handled according to its type.
-- WARNING: This function will only return the first two return values
-- of the pcalled function!!
local function do_pcall(func, ...)
  local rc, err_or_res, second_res = pcall(func, ...)

  if not rc then
    if type(err_or_res) == "table" then
      return nil, err_or_res.errcode, err_or_res.errmsg
    end
    return nil, 9002, "error not a table: " .. tostring(err_or_res)
  end
  return err_or_res, second_res
end

--- Do the actual 'commit' at the end of a transaction, throws
-- an error if anything goes wrong.
-- This function should be pcall()'d.
local function commit(self, uuid)
  self.store:commit(uuid)
  self.commitapply:commitTransaction()
  return true
end

--- Wrapper around the commit functionality.
local function commitTransaction(self, uuid)
  return do_pcall(commit, self, uuid)
end

--- Do the actual 'revert' at the end of a failed transaction, throws
-- an error if anything goes wrong.
-- This function should be pcall()'d.
local function revert(self, uuid)
  self.store:revert()
  self.commitapply:revertTransaction()
  return true
end

--- Wrapper around the revert functionality.
local function revertTransaction(self, uuid)
  return do_pcall(revert, self, uuid)
end

--- Indicate a transaction is about to commence.
-- Currently does not have to be pcall()'d
local function startTransaction(self, uuid)
  local success, errcode, errmsg = revertTransaction(self)
  if success then
    self.commitapply:startTransaction()
    return true
  end
  return success, errcode, errmsg
end

local function do_transaction_pcall(func, self, uuid, ...)
  startTransaction(self)
  local res, errcode, errmsg = do_pcall(func, self, uuid, ...)
  if not res and errcode then
    revertTransaction(self, uuid)
  else
    commitTransaction(self, uuid)
  end
  return res, errcode, errmsg
end

local function call_cb(cb, ...)
  local rc, err, errmsg = pcall(cb, ...)
  if not rc then  -- callback threw an error; error message is in 'err'
    fault.InternalError(err)
  elseif errmsg then
    -- callback returned nil + error message
    -- note that we can't just check on 'err' because it is
    -- perfectly OK for the callback to return nothing when
    -- everything went fine
    fault.InternalError(errmsg)
  end
end

-- Retrieve the parameters as indicated by `path` but catching
-- any errors thrown so the retrieval continues.
local function get_without_abort(uuid, store, navigate, path, cb)
  -- create object iterator
  local rc, obj_it, obj_it_state = pcall(navigate, store, uuid, path, "get")
  if not rc then
    -- failed to create iterator; `obj_it` is now the error object
    call_cb(cb, path, "", "", "", obj_it.errcode, obj_it.errmsg)
    return
  end
  local current_path = path
  -- we have an object iterator; invoke it until it ends
  while true do
    local obj
    rc, obj = pcall(obj_it, obj_it_state)
    if not rc then
      -- failed to get the next object; `obj` is now the error object
      -- The last path that was handled by the object iterator (and thus caused
      -- the failure) is available in obj_it_state and is not necessarily the same as current_path.
      -- Reporting this path in the callback will give a better error message.
      call_cb(cb, obj_it_state.objpath, "", "", "", obj.errcode, obj.errmsg)
      -- stop the object iteration
      break
    end
    if not obj then
      -- iteration ended
      break
    end
    -- create parameter iterator
    current_path = obj:getPath()
    local param_it, param_it_state
    rc, param_it, param_it_state = pcall(obj.params, obj)
    if not rc then
      -- failed to create iterator; `param_it` is now the error object
      call_cb(cb, current_path, "", "", "", param_it.errcode, param_it.errmsg)
      -- don't break; move on to the next object
    else
      -- we have a param iterator; invoke it until it ends
      while true do
        local param
        rc, param = pcall(param_it, param_it_state)
        if not rc then
          -- failed to get next param; `param` is now the error object
          call_cb(cb, current_path, "", "", "", param.errcode, param.errmsg)
          -- stop the param iteration
          break
        end
        if not param then
          -- iteration ended
          break
        end
        -- get the parameter data
        local ppath, pname, pvalue, ptype
        rc, ppath, pname, pvalue, ptype = pcall(param.get, param)
        if not rc then
          -- Failed to get parameter data; `ppath` is now the error object.
          -- Retrieve the param name using the getName() method which always succeeds.
          -- We don't need the first return value so store it in a variable we don't need.
          ptype, pname = param:getName()
          call_cb(cb, current_path, pname, "", "", ppath.errcode, ppath.errmsg)
          -- don't break; move on to the next parameter
        else
          call_cb(cb, ppath, pname, pvalue, ptype)
        end
      end
    end
  end
end

-- Do the actual 'get'; throw error if anything goes wrong.
-- This function should be pcall()'d
local function get(self, uuid, no_abort_on_error, paths, cb)
  local store = self.store
  local navigate = store.navigate
  for _, path in ipairs(paths) do
    if no_abort_on_error then
      get_without_abort(uuid, store, navigate, path, cb)
    else
      for obj in navigate(store, uuid, path, "get") do
        for param in obj:params() do
          call_cb(cb, param:get())
        end
      end
    end
  end
  return true
end

--- getParameterValues
-- @param uuid Identifier of the requester
-- @param no_abort_on_error Boolean indicating whether an error should abort the request
--   processing or Transformer should continue and return as much data as possible.
-- @param paths Array of exact or partial paths to retrieve.
-- @param cb Callback function that will be invoked for each parameter.
--     Arguments to the callback function will be:
--     - Full path of the object.
--     - Name of the parameter.
--     - Value of the parameter (as a string).
--     - Type of the parameter in the datamodel (as a string).
--     - Optionally an error code. If present the parameter name is filled in when possible
--        and otherwise will be an empty string. The value and type will be empty strings,
--        and the path will be an approximation of where the error occurred.
--     - If an error code was given then there will also be an error message.
-- @return true or nil, errorcode, errormsg
function Transformer:getParameterValues(uuid, no_abort_on_error, paths, cb)
  -- The get function can cause a synchronization between the mappings
  -- and our database. The synchronization however is only persisted on
  -- successful completion of a transaction, so we wrap our get in a
  -- transaction model.
  return do_transaction_pcall(get, self, uuid, no_abort_on_error, paths, cb)
end

-- Do the actual 'get list'; throw error if anything goes wrong.
-- This function should be pcall()'d
local function getParams(self, uuid, path, cb)
    for obj in self.store:navigate(uuid, path, "getlist") do
        for param in obj:params() do
            call_cb(cb, param:getName())
        end
    end
    return true
end

--- retrieve all parameters (but no values)
-- @param uuid Identifier of the requester
-- @param path Exact or partial path to retrieve.
-- @param cb Callback function that will be invoked for each parameter.
--     Arguments to the callback function will be:
--     - Full path of the object.
--     - Name of the parameter.
-- @return true or nil, errorcode, errormsg
function Transformer:getParameterList(uuid, path, cb)
  -- The getParameterList function can cause a synchronization between the mappings
  -- and our database. The synchronization however is only persisted on
  -- successful completion of a transaction, so we wrap our get in a
  -- transaction model.
  return do_transaction_pcall(getParams, self, uuid, path, cb)
end

-- the actual get count.
-- This does a getlist (so no values need to be retrieved) and just counts
-- the number of parameters returned.
local function getcount(self, uuid, path)
  local count = 0
    for obj in self.store:navigate(uuid, path, "getlist") do
        for _ in obj:params() do
          count = count + 1
        end
    end
    return count
end

--- Retrieve the number of parameters for the given path.
-- @param uuid Identifier of the requester
-- @param path Exact or partial path to traverse
-- @param cb Callback function that will be called once with a single parameter
--           containing the the count of parameters.
-- @returns count or nil, errorcode, errormsg
function Transformer:getCount(uuid, path)
  -- The getCount function can cause a synchronization between the mappings
  -- and our database. The synchronization however is only persisted on
  -- successful completion of a transaction, so we wrap our get in a
  -- transaction model.
  return do_transaction_pcall(getcount, self, uuid, path)
end

local function getPN(self, uuid, path, level, cb)
  for obj in self.store:navigate(uuid, path, "getpn", level) do
    -- when 'path' is an exact path we don't want information on the
    -- object itself; in that case the isWritable() method will
    -- return nil
    local ppath, writable = obj:isWritable()
    if ppath then
      call_cb(cb, ppath, "", writable)
    end
    for param in obj:params() do
      call_cb(cb, param:isWritable())
    end
  end
  return true
end

--- getParameterNames
-- @param uuid Identifier of the requester
-- @param path Exact or partial path to retrieve.
-- @param level Number (0, 1 or 2 are allowed) indicating whether to restrict
--              the results to only that level in the datamodel hierarchy.
--              For more information on the meaning of this parameter see
--              ./doc/getparameternames.md
-- @param cb Callback function that will be invoked for each result.
--     Arguments to the callback function will be:
--     - Full path of the object.
--     - Name of the parameter. Can be empty string when not applicable.
--     - Boolean indicating whether the parameter/object is writable.
-- @return true or nil, errorcode, errormsg
function Transformer:getParameterNames(uuid, path, level, cb)
  -- The getPN function can cause a synchronization between the mappings
  -- and our database. The synchronization however is only persisted on
  -- successful completion of a transaction, so we wrap our getPN in a
  -- transaction model.
  return do_transaction_pcall(getPN, self, uuid, path, level, cb)
end

local function set(self, uuid, path, value)
    for obj in self.store:navigate(uuid, path, "set") do
        for param in obj:params() do
            param:set(value)
        end
    end
    return true
end

local function setParameterValue(self, uuid, path, value)
    return do_pcall(set, self, uuid, path, value)
end

--- setParameterValues
-- @param uuid Identifier of the requester
-- @param setValues a list of param, value pairs
-- @return success, errors with:
--    success, true if all OK, false if errors occurred
--    errors, the list of errors {path, errcode, errmsg}
--    in case of success, errors is nil
function Transformer:setParameterValues(uuid, setValues)
    local errors
    local duplicateFinder = {}
    startTransaction(self)
    for _, pv in ipairs(setValues) do
      if duplicateFinder[pv.path] then
        errors = errors or {} -- create if needed
        if duplicateFinder[pv.path] == 1 then
          -- Add an extra error for the first entry.
          errors[#errors+1] = {pv.path, 9005, "Duplicate entry"}
        end
        errors[#errors+1] = {pv.path, 9005, "Duplicate entry"}
        duplicateFinder[pv.path] = duplicateFinder[pv.path] + 1
      else
        duplicateFinder[pv.path] = 1
      end
    end
    -- We still need to go through all the sets to generate any other possible
    -- errors.
    for _, pv in ipairs(setValues) do
        local path, value = pv.path, pv.value
        local ok, errcode, errmsg = setParameterValue(self, uuid, path, value)
        if not ok then
            errors = errors or {} -- create if needed
            errors[#errors+1] = {path, errcode, errmsg}
        end
    end
    if errors and #errors ~= 0 then
      -- TODO what to do if commit or revert fails? SPV is currently not able to
      -- return an error?
      revertTransaction(self, uuid)
    else
      commitTransaction(self, uuid)
    end
    return errors==nil, errors
end

--- Apply all changes that have been done but not applied yet.
-- This usually triggers the restarting/reloading of the daemons
-- affected by the configuration changes.
-- @param uuid Identifier of the requester
function Transformer:apply(uuid)
    self.commitapply:apply()
end

-- Do the actual 'add'; throws error if anything goes wrong.
-- This function should be pcall()'d
local function add(self, uuid, path, name)
  for obj in self.store:navigate(uuid, path, "add") do
    --Should only be one
    return obj:add(name)
  end
end

--- addObject
-- @param uuid Identifier of the requester
-- @param path a path to which an object should be added
-- @param name an optional name to be used (named MI only)
-- @return instance or nil, errorcode, errormsg
function Transformer:addObject(uuid, path, name)
  return do_transaction_pcall(add, self, uuid, path, name)
end

-- Do the actual 'delete'; throws error if anything goes wrong.
-- This function should be pcall()'d
local function delete(self, uuid, path)
  for obj in self.store:navigate(uuid, path, "del") do
    obj:delete()
  end
  return true
end

--- deleteObject
-- @param uuid Identifier of the requester
-- @param path a path which needs to be deleted
-- @return true or nil, errorcode, errormsg
function Transformer:deleteObject(uuid, path)
  return do_transaction_pcall(delete, self, uuid, path)
end

-- helper to call xref.resolve from transaction_pcall
local function xref_resolve(self, uuid, ...)
  return xref.resolve(...)
end

--- Resolve an objecttype path and a key to the corresponding datamodel path.
-- @param uuid Identifier of the requester
-- @param typePath The path which needs resolving
-- @param key The key of the required path instance
-- @return string or nil, errorcode, errormsg
function Transformer:resolve(uuid, typePath, key)
    self.store:setClientUUID(uuid)
    local rc, errcode, errmsg = do_transaction_pcall(xref_resolve, self, uuid, self.store, typePath, key)

    if not rc and not errcode then
        return ""
    end

    return rc, errcode, errmsg
end

local function xref_tokey(self, uuid, ...)
  return xref.tokey(...)
end

--- Lookup the key associated with the given object path.
-- @param uuid Identifier of the requester
-- @param objectPath The object path to convert
-- @return key + typepath or nil, errorcode, errormsg
function Transformer:tokey(uuid, objectPath)
    self.store:setClientUUID(uuid)
    local rc, errcode, errmsg = do_transaction_pcall(xref_tokey, self, uuid, self.store, objectPath)

    if not rc and not errcode then
        return ""
    end

    return rc, errcode, errmsg
end

function Transformer:subscribe(uuid, path, addr, subscr_type, options)
  local eventhor = self.eventhor
  local rc, errcode, errmsg = do_pcall(eventhor.addSubscription, eventhor, uuid, path, addr, subscr_type, options)
  return rc, errcode, errmsg
end

function Transformer:unsubscribe(uuid, subscr_id)
  local eventhor = self.eventhor
  local rc, errcode, errmsg = do_pcall(eventhor.removeSubscription, eventhor, uuid, subscr_id)
  return rc, errcode, errmsg
end

local M = {}

local function init(config)
  local store = require("transformer.typestore").new(config.persistency_location,
                                                     config.persistency_name)
  local self = {
    store = store,
    commitapply = require("transformer.commitapply").new(config.commitpath),
    eventhor = require("transformer.eventhor").new(store),
  }
  return setmetatable(self, Transformer)
end

--- Initializes Transformer and loads the maps from the location
-- specified in the configuration.
-- @param config a table containing the configuration parameters:
--     mappath: ':' separated search path for mapping files. It will try to register all .map files.
--     commitpath: location on the filesystem of commit & apply rules.
--     persistency_location: location on the filesystem where to store persistent information
--                           (e.g. instance numbers and their relation to keys)
--     persistency_name : (optional) the name of the database file, defaults to
--                        transformer.db
--     ignore_patterns : (optional) A table of patterns for typepaths that need to be ignored.
--     vendor_patterns : (optional) A table of patterns of vendor extensions for paths that should be allowed.
--     unhide_patterns : (optional) A table of patterns for typepaths that must not be hidden.
-- @return An object on which you can call various methods or nil + error
--         message if something went wrong.
function M.init(config)
    if not config.mappath then
        return nil, "no mappath defined"
    end
    if not config.commitpath then
        return nil, "no commitpath defined"
    end
    if not config.persistency_location then
        return nil, "no persistency location defined"
    end

    local rc, self = pcall(init, config)
    if not rc then
        return nil, self  -- self is the error message in this case
    end

    -- split config.mappath on : separators and load the maps in each of them
    -- TODO: move this into mapload.load_all_maps so we can reuse the map env
    local mapload = require("transformer.mapload")
    for path in config.mappath:gmatch("([^:]+)") do
        local rc, err = mapload.load_all_maps(self.store, self.commitapply, path, config.ignore_patterns, config.vendor_patterns, config.unhide_patterns)
        if not rc then
            self:close()
            return nil, err
        end
    end
    return self
end

return M
