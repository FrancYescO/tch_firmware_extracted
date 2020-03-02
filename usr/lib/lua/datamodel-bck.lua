--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

-------------------------------------------------------------
-- Module to easily talk to Transformer.
--
-- The module takes care of setting up a communication
-- channel towards Transformer. Internally it uses a socket
-- pool to avoid having to create and close a socket on
-- every request.
--
-- At this moment the module API does not use callbacks.
-- All results of an API call will be returned in one go.
-- This will cause a memory spike (and possibly an OOM error)
-- if you request a large part of the datamodel.
-------------------------------------------------------------

local uds = require("tch.socket.unix")
local dgram = uds.dgram
local max_size = uds.MAX_DGRAM_SIZE
local cloexec = uds.SOCK_CLOEXEC
local msg = require("transformer.msg").new()
local fault = require("transformer.fault")
local GPV_REQ, GPV_RESP, SPV_REQ, SPV_RESP, ADD_REQ, ADD_RESP, DEL_REQ
local GPN_RESP, GPN_REQ, DEL_RESP, RESOLVE_REQ, RESOLVE_RESP, APPLY, ERROR
local SUBSCRIBE_REQ, SUBSCRIBE_RESP, UNSUBSCRIBE_REQ, UNSUBSCRIBE_RESP
local GPL_REQ, GPL_RESP, GPC_REQ, GPC_RESP
local GPV_NO_ABORT_REQ, GPV_NO_ABORT_RESP

do
  GPV_REQ = msg.tags.GPV_REQ
  GPV_RESP = msg.tags.GPV_RESP
  SPV_REQ = msg.tags.SPV_REQ
  SPV_RESP = msg.tags.SPV_RESP
  ADD_REQ = msg.tags.ADD_REQ
  ADD_RESP = msg.tags.ADD_RESP
  DEL_REQ = msg.tags.DEL_REQ
  DEL_RESP = msg.tags.DEL_RESP
  GPN_REQ = msg.tags.GPN_REQ
  GPN_RESP = msg.tags.GPN_RESP
  RESOLVE_REQ = msg.tags.RESOLVE_REQ
  RESOLVE_RESP = msg.tags.RESOLVE_RESP
  SUBSCRIBE_REQ = msg.tags.SUBSCRIBE_REQ
  SUBSCRIBE_RESP = msg.tags.SUBSCRIBE_RESP
  UNSUBSCRIBE_REQ = msg.tags.UNSUBSCRIBE_REQ
  UNSUBSCRIBE_RESP = msg.tags.UNSUBSCRIBE_RESP
  GPL_REQ = msg.tags.GPL_REQ
  GPL_RESP = msg.tags.GPL_RESP
  GPC_REQ = msg.tags.GPC_REQ
  GPC_RESP = msg.tags.GPC_RESP
  APPLY = msg.tags.APPLY
  ERROR = msg.tags.ERROR
  GPV_NO_ABORT_REQ = msg.tags.GPV_NO_ABORT_REQ
  GPV_NO_ABORT_RESP = msg.tags.GPV_NO_ABORT_RESP
end

local select, ipairs, pairs, type =
      select, ipairs, pairs, type

-- minimum number of sockets to keep in the socket pool
local min_sks = 3
-- pool of sockets to use to communicate with Transformer
local sk_pool = {}
-- dummy tainting function; it's replaced with the real
-- tainting function when tainting is enabled
local function taint(value)
  return value
end
-- dummy istainted function; it's replaced with the real
-- istainted function when tainting is enabled
local function istainted()
  return false
end
-- dummy untaint function; it's replaced with the real
-- untaint function when tainting is enabled
local function untaint(value)
  return value
end

-- get sk from pool; creating one if none available
local function get_sk()
  local sk
  local nb_sks = #sk_pool
  if nb_sks > 0 then
    sk = sk_pool[nb_sks]
    sk_pool[nb_sks] = nil
  else
    local errmsg
    sk, errmsg = dgram(cloexec)
    if not sk then
      return nil, errmsg
    end
    local rc
    rc, errmsg = sk:connect("transformer")
    if not rc then
      sk:close()
      return nil, errmsg
    end
  end
  return sk
end

-- put sk back in pool if not already full
local function release_sk(sk)
  local nb_sks = #sk_pool
  if nb_sks < min_sks then
    sk_pool[nb_sks + 1] = sk
  else
    sk:close()
  end
end

local function send_on_sk(data)
  -- send the request
  local sk, errmsg = get_sk()
  if not sk then
    return nil, errmsg
  end 
  local rc
  rc, errmsg = sk:send(data)
  if not rc then
    sk:close()
    return nil, errmsg
  end

  return sk
end

local M = {}

function M.enable_tainting()
  taint = string.taint
  istainted = string.istainted
  untaint = string.untaint
end

local function encode_path(path)
  path = untaint(path)
  if type(path) ~= "string" then
    return false
  end
  msg:encode(path)
  return true
end

local function encode_get_with_abort(uuid, tbl_of_paths, abort_on_error)
  if abort_on_error then
    msg:init_encode(GPV_REQ, max_size, uuid)
  else
    msg:init_encode(GPV_NO_ABORT_REQ, max_size, uuid)
  end
  for _, path in ipairs(tbl_of_paths) do
    if not encode_path(path) then
      return nil, "not string argument", fault.INVALID_ARGUMENTS
    end
  end
  return true
end

local function encode_get(uuid, ...)
  return encode_get_with_abort(uuid, {...}, true)
end

---
-- Retrieve the values of the given datamodel location(s).
-- This function has two signatures:
--   get(uuid, path1, path2, ...)
--     Pass it one or more strings, each either a partial or exact path.
-- and
--   get(uuid, {path1, path2,...}, abort_on_error)
--     The partial or exact paths are passed in as a table. The optional third
--     parameter indicates if we wish to abort in case of an error or not.
-- Returns array of tables with 'path', 'param', 'value' and 'type' fields.
-- If an error occurs and the abort_on_error flag is not set, a second array
-- is returned of tables with 'path, 'param' and 'errmsg' fields.
-- If an error occurs and the abort_on_error flag is set or the error is unrecoverable,
-- nil + error message + error code is returned.
function M.get(uuid, first_arg, second_arg, ...)
  if uuid == nil or uuid == "" then
    return nil, "no UUID", fault.INVALID_ARGUMENTS
  end
  if not first_arg then
    return nil, "no data", fault.INVALID_ARGUMENTS
  end
  local ok, errmsg, errcode
  if type(first_arg) == "table" then
    ok, errmsg, errcode = encode_get_with_abort(uuid, first_arg, second_arg)
  else
    ok, errmsg, errcode = encode_get(uuid, first_arg, second_arg, ...)
  end
  if not ok then
    return ok, errmsg, errcode
  end
  msg:mark_last()
  -- send the request
  local sk, errmsg = send_on_sk(msg:retrieve_data())
  if not sk then
    return nil, errmsg, fault.INTERNAL_ERROR
  end
  -- process the response
  local results = {}
  local errors = {}
  local is_last = false
  while not is_last do
    local tag, resp
    local data = sk:recv()
    tag, is_last = msg:init_decode(data)
    if tag == GPV_RESP then
      resp = msg:decode()
      for _, value in ipairs(resp) do
        value.value = taint(value.value)
        results[#results + 1] = value
      end
    elseif tag == ERROR then
      resp = msg:decode()
      release_sk(sk)
      return nil, resp.errmsg, resp.errcode
    elseif tag == GPV_NO_ABORT_RESP then
      resp = msg:decode()
      for _, single_resp in ipairs(resp) do
        if single_resp.type == 'error' then
          single_resp.errmsg = single_resp.value
          single_resp.value = nil
          single_resp.type = nil
          errors[#errors + 1] = single_resp
        else
          single_resp.value = taint(single_resp.value)
          results[#results + 1] = single_resp
        end
      end
    else
      release_sk(sk)
      return nil, "invalid response type", fault.INTERNAL_ERROR
    end
  end
  release_sk(sk)
  if #errors == 0 then
    errors = nil
  end
  return results, errors
end

---
-- Retrieve the parameter names of the given datamodel location.
-- Pass it one string representing either a partial or an exact 
-- datamodel location, and a boolean representing wether or not
-- we only want to retreive the next level.
-- Returns array of tables with 'path', 'name' and 'writable' fields
-- or nil + error message + error code.
-- Throws an error if you pass anything other than a string.
function M.getPN(uuid, path, nextlevel)
  if uuid == nil or uuid == "" then
    return nil, "no UUID", fault.INVALID_ARGUMENTS
  end
  if path == nil or path == "" then
    return nil, "no data", fault.INVALID_ARGUMENTS
  end
  if type(path) ~= "string" then
    return nil, "not string argument", fault.INVALID_ARGUMENTS
  end
  if type(nextlevel) ~= "boolean" then
    return nil, "not boolean argument", fault.INVALID_ARGUMENTS
  end
  -- construct message to send to Transformer
  msg:init_encode(GPN_REQ, max_size, uuid)
  -- a next level value of 0 is only used in cwmpd
  msg:encode(path, nextlevel and 1 or 2)
  msg:mark_last()
  local sk, errmsg = send_on_sk(msg:retrieve_data())
  if not sk then
    return nil, errmsg, fault.INTERNAL_ERROR
  end
  -- process the response
  local results = {}
  local is_last = false
  while not is_last do
    local tag, resp
    local data = sk:recv()
    tag, is_last = msg:init_decode(data)
    if tag == GPN_RESP then
      resp = msg:decode()
      for _, value in ipairs(resp) do
        results[#results + 1] = value
      end
    elseif tag == ERROR then
      resp = msg:decode()
      release_sk(sk)
      return nil, resp.errmsg, resp.errcode
    else
      release_sk(sk)
      return nil, "invalid response type", fault.INTERNAL_ERROR
    end
  end
  release_sk(sk)
  return results
end

---
-- Set the given datamodel location(s) to the given value(s).
-- Pass it either a path and value string or a table of path/value pairs.
-- Returns 'true' if all sets have been applied or nil + array of tables
-- with 'errcode', 'errmsg' and optionally 'path' fields.
-- Throws an error if you pass anything other than strings.
function M.set(uuid, arg1, arg2)
  if uuid == nil or uuid == "" then
    return nil, { { errcode = fault.INVALID_ARGUMENTS, errmsg = "no UUID" } }
  end
  -- construct message to send to Transformer
  msg:init_encode(SPV_REQ, max_size, uuid)
  -- if 'arg2' is present assume the caller passed a path and value string
  if arg2 then
    if type(arg1) ~= "string" or
       (type(arg2) ~= "string" and not istainted(arg2)) then
      return nil, { { errcode = fault.INVALID_ARGUMENTS, errmsg = "not string argument" } }
    end
    msg:encode(arg1, untaint(arg2))
  else -- otherwise assume 'arg1' is a table of (path, value) pairs
    if type(arg1) ~= "table" then
      return nil, { { errcode = fault.INVALID_ARGUMENTS , errmsg = "not table of strings argument" } }
    end
    local count = 0
    for path, value in pairs(arg1) do
      if type(path) ~= "string" or
         (type(value) ~= "string" and not istainted(value)) then
        return nil, { { errcode = fault.INVALID_ARGUMENTS, errmsg = "not table of strings argument" } }
      end
      count = count + 1
      msg:encode(path, untaint(value))
    end
    if count == 0 then
      return nil, { { errcode = fault.INVALID_ARGUMENTS, errmsg = "not table of strings argument" } }
    end
  end
  msg:mark_last()
  -- send the request
  local sk, errmsg = send_on_sk(msg:retrieve_data())
  if not sk then
    return nil, { { errcode = fault.INTERNAL_ERROR, errmsg = errmsg } }
  end
  -- process the response
  local errors
  local is_last = false
  while not is_last do
    local tag, resp
    local data = sk:recv()
    tag, is_last = msg:init_decode(data)
    if tag == SPV_RESP then
      resp = msg:decode()
      if #resp > 0 then
        if errors then
          for _, err in ipairs(resp) do
            errors[#errors + 1] = err
          end
        else
          errors = resp
        end
      end
    elseif tag == ERROR then
      resp = msg:decode()
      release_sk(sk)
      return nil, { { errcode = resp.errcode , errmsg = resp.errmsg } }
    else
      release_sk(sk)
      return nil, { { errcode = fault.INTERNAL_ERROR, errmsg = "invalid response type" } }
    end
  end
  release_sk(sk)
  if errors then
    return nil, errors
  end
  return true
end

---
-- Add a new instance at the given datamodel location.
-- Pass it one string representing a writable multi-instance path.
-- Pass it an optional second string representing the name to be used.
-- Returns the instance number or name of the new instance, or nil +
-- error message + error code.
-- Throws an error if you pass anything other than a string.
function M.add(uuid, path, name)
  if uuid == nil or uuid == "" then
    return nil, "no UUID", fault.INVALID_ARGUMENTS
  end
  local name_t = type(name)
  if type(path) ~= "string" or (name_t ~= "string" and name_t ~= "nil") then
    return nil, "not string argument", fault.INVALID_ARGUMENTS
  end
  -- construct message to send to Transformer
  msg:init_encode(ADD_REQ, max_size, uuid)
  msg:encode(path, name)
  msg:mark_last()
  -- send the request
  local sk, errmsg = send_on_sk(msg:retrieve_data())
  if not sk then
    return nil, errmsg, fault.INTERNAL_ERROR
  end
  -- process the response
  local tag, is_last, resp
  local data = sk:recv()
  tag, is_last = msg:init_decode(data)
  if tag == ADD_RESP then
    resp = msg:decode()
    release_sk(sk)
    return resp
  elseif tag == ERROR then
    resp = msg:decode()
    release_sk(sk)
    return nil, resp.errmsg, resp.errcode
  end
  release_sk(sk)
  return nil, "invalid response type", fault.INTERNAL_ERROR
end

---
-- Delete the instance at the given datamodel location.
-- Pass it one string representing an instance in a multi-instance path.
-- Returns true or nil + error message + error code.
-- Throws an error if you pass anything other than a string.
function M.del(uuid, path)
  if uuid == nil or uuid == "" then
    return nil, "no UUID", fault.INVALID_ARGUMENTS
  end
  if type(path) ~= "string" then
    return nil, "not string argument", fault.INVALID_ARGUMENTS
  end
  -- construct message to send to Transformer
  msg:init_encode(DEL_REQ, max_size, uuid)
  msg:encode(path)
  msg:mark_last()
  -- send the request
  local sk, errmsg = send_on_sk(msg:retrieve_data())
  if not sk then
    return nil, errmsg, fault.INTERNAL_ERROR
  end
  -- process the response
  local tag, is_last, resp
  local data = sk:recv()
  tag, is_last = msg:init_decode(data)
  if tag == DEL_RESP then
    release_sk(sk)
    return true
  elseif tag == ERROR then
    resp = msg:decode()
    release_sk(sk)
    return nil, resp.errmsg, resp.errcode
  end
  release_sk(sk)
  return nil, "invalid response type", fault.INTERNAL_ERROR
end

---
-- Resolve the specified key path to the instance with the specified key.
-- Pass it one string representing a type path and one string representing
-- the requested instance's key.
-- Returns the resolved path of the instance or nil + error message. If
-- the path instance was not found the returned path will be an empty string.
-- Throws an error if you pass anything other than a string.
function M.resolve(uuid, typePath, key)
  if uuid == nil or uuid == "" then
    return nil, "no UUID"
  end
  if type(typePath) ~= "string" or type(key) ~= "string" then
    return nil, "invalid argument"
  end
  -- construct message to send to Transformer
  msg:init_encode(RESOLVE_REQ, max_size, uuid)
  msg:encode(typePath, key)
  msg:mark_last()
  -- send the request
  local sk, errmsg = send_on_sk(msg:retrieve_data())
  if not sk then
    return nil, errmsg
  end
  -- process the response
  local tag, is_last, resp
  local data = sk:recv()
  tag, is_last = msg:init_decode(data)
  if tag == RESOLVE_RESP then
    resp = msg:decode()
    release_sk(sk)
    return resp
  elseif tag == ERROR then
    resp = msg:decode()
    release_sk(sk)
    return nil, resp.errmsg
  end
  release_sk(sk)
  return nil, "invalid response type"
end

---
-- Apply (in the background) all configuration changes
-- that have been done earlier.
-- Returns 'true' if the 'apply' message has been sent successfully
-- or nil + error message otherwise.
function M.apply(uuid)
  if uuid == nil or uuid == "" then
    return nil, "no UUID", fault.INVALID_ARGUMENTS
  end
  msg:init_encode(APPLY, max_size, uuid)
  msg:encode()
  msg:mark_last()
  -- send the request
  local sk, errmsg = send_on_sk(msg:retrieve_data())
  if not sk then
    return nil, errmsg, fault.INTERNAL_ERROR
  end
  return true
end

function M.subscribe(uuid, path, address, subtype, options)
  if uuid == nil or uuid == "" then
    return nil, "no UUID"
  end
  if type(uuid) ~= "string" or type(path) ~= "string" or type(address) ~= "string" 
    or type(subtype) ~= "number" or subtype < 0 or subtype > 7 
    or type(options) ~= "number" then
    return nil, "invalid argument"
  end
  msg:init_encode(SUBSCRIBE_REQ, max_size, uuid)
  msg:encode(path, address, subtype, options)
  msg:mark_last()
  -- send the request
  local sk, errmsg = send_on_sk(msg:retrieve_data())
  if not sk then
    return nil, errmsg
  end
  -- process the response
  local tag, is_last, resp
  local data = sk:recv()
  tag, is_last = msg:init_decode(data)
  if tag == SUBSCRIBE_RESP then
    resp = msg:decode()
    release_sk(sk)
    return resp.id, resp.nonevented
  elseif tag == ERROR then
    resp = msg:decode()
    release_sk(sk)
    return nil, resp.errmsg
  end
  release_sk(sk)
  return nil, "invalid response type"
end

function M.unsubscribe(uuid, subscr_id)
  if uuid == nil or uuid == "" then
    return nil, "no UUID"
  end
  if type(uuid) ~= "string" or type(subscr_id) ~= "number" then
    return nil, "invalid argument"
  end
  msg:init_encode(UNSUBSCRIBE_REQ, max_size, uuid)
  msg:encode(subscr_id)
  msg:mark_last()
  -- send the request
  local sk, errmsg = send_on_sk(msg:retrieve_data())
  if not sk then
    return nil, errmsg
  end
  -- process the response
  local tag, is_last, resp
  local data = sk:recv()
  tag, is_last = msg:init_decode(data)
  if tag == UNSUBSCRIBE_RESP then
    release_sk(sk)
    return true
  elseif tag == ERROR then
    resp = msg:decode()
    release_sk(sk)
    return nil, resp.errmsg
  end
  release_sk(sk)
  return nil, "invalid response type"
end

---
-- Retrieve the parameter list of the given datamodel location(s).
-- Pass it one or more strings, each either a partial or exact path.
-- Returns array of tables with 'path' and 'param' fields
-- or nil + error message.
-- Throws an error if you pass anything other than strings.
function M.getPL(uuid, ...)
  if uuid == nil or uuid == "" then
    return nil, "no UUID"
  end
  local nb_args = select("#", ...)
  if nb_args == 0 then
    return nil, "no data"
  end
  -- construct message to send to Transformer
  msg:init_encode(GPL_REQ, max_size, uuid)
  for i = 1, nb_args do
    local path = select(i, ...)
    if not encode_path(path) then
      return nil, "not string argument"
    end
  end
  msg:mark_last()
  -- send the request
  local sk, errmsg = send_on_sk(msg:retrieve_data())
  if not sk then
    return nil, errmsg
  end
  -- process the response
  local results = {}
  local is_last = false
  while not is_last do
    local tag, resp
    local data = sk:recv()
    tag, is_last = msg:init_decode(data)
    if tag == GPL_RESP then
      resp = msg:decode()
      for _, value in ipairs(resp) do
        results[#results + 1] = value
      end
    elseif tag == ERROR then
      resp = msg:decode()
      release_sk(sk)
      return nil, resp.errmsg
    end
  end
  release_sk(sk)
  return results
end

---
-- Retrieve the number of parameters of the given datamodel location(s).
-- Pass it one or more strings, each either a partial or exact path.
-- Returns a count value or nil + error message.
-- Throws an error if you pass anything other than strings.
function M.getPC(uuid, ...)
  if uuid == nil or uuid == "" then
    return nil, "no UUID"
  end
  local nb_args = select("#", ...)
  if nb_args == 0 then
    return nil, "no data"
  end
  -- construct message to send to Transformer
  msg:init_encode(GPC_REQ, max_size, uuid)
  for i = 1, nb_args do
    local path = select(i, ...)
    if not encode_path(path) then
      return nil, "not string argument"
    end
  end
  msg:mark_last()
  -- send the request
  local sk, errmsg = send_on_sk(msg:retrieve_data())
  if not sk then
    return nil, errmsg
  end
  -- process the response
  local tag, resp
  local data = sk:recv()
  tag = msg:init_decode(data)
  if tag == GPC_RESP then
    resp = msg:decode()
    release_sk(sk)
    return resp
  elseif tag == ERROR then
    resp = msg:decode()
    release_sk(sk)
    return nil, resp.errmsg
  end
  release_sk(sk)
  return nil, "invalid response type"
end

return M
