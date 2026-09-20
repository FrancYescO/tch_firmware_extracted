--/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
--** Copyright (c) 2016 - 2016  -  Technicolor Delivery Technologies, SAS **
--** - All Rights Reserved                                                **
--** Technicolor hereby informs you that certain portions                 **
--** of this software module and/or Work are owned by Technicolor         **
--** and/or its software providers.                                       **
--** Distribution copying and modification of all such work are reserved  **
--** to Technicolor and/or its affiliates, and are not permitted without  **
--** express written authorization from Technicolor.                      **
--** Technicolor is registered trademark and trade name of Technicolor,   **
--** and shall not be used in any manner without express written          **
--** authorization from Technicolor                                       **
--*************************************************************************/

---
-- Web Service API implementation
--
-- This module should be used in conjuction with an access control module (for
-- example the @{webservice.accesscontrol_token} module) in `nginx.conf`.
-- @module webservice.api
-- @usage
-- content_by_lua '
--   local role = require("webservice.accesscontrol_token").authenticate()
--   require("webservice.api").process(role)
-- ';

local json = require("dkjson")
local dm = require("datamodel")
local fault = require("transformer.fault")
local ngx = ngx
local type, unpack, ipairs, pairs = type, unpack, ipairs, pairs
local istainted = string.istainted

local function error_response(errorcode, errormessage)
  return nil, { errorcode = errorcode, errormessage = errormessage }
end

local function get_data()
  ngx.req.read_body()
  local data = ngx.req.get_body_data()
  if not data then
    ngx.log(ngx.ERR, "could not read body data")
    return error_response(fault.INTERNAL_ERROR, "could not read body data")
  end
  return data
end

local function unknown(_, req)
  ngx.log(ngx.WARN, "unknown command: ", req.command)
  return error_response(fault.INVALID_ARGUMENTS, "unknown command")
end

local function get(role, req)
  if type(req.data) ~= "table" then
    return error_response(fault.INVALID_ARGUMENTS, "invalid data")
  end
  -- note: authorization is only done on request paths, not on
  -- response paths!
  for _, path in ipairs(req.data) do
    if (type(path) == "string" or istainted(path)) and
       not role:authorize_path(path) then
      return error_response(fault.INVALID_NAME, "invalid path: " .. path)
    end
  end
  local data, errmsg, errcode = dm.get(unpack(req.data))
  if not data then
    return error_response(errcode, errmsg)
  end
  local response = {}
  for _, param in ipairs(data) do
    local path = param.path
    param.path = nil
    local obj = response[path]
    if not obj then
      obj = {}
      response[path] = obj
    end
    local pname = param.param
    param.param = nil
    obj[pname] = param
  end
  return response
end

local function set(role, req)
  local data, errors
  local authorized = true
  if type(req.data) == "table" then
    for path in pairs(req.data) do
      if (type(path) == "string" or istainted(path)) and
         not role:authorize_path(path) then
        authorized = false
        errors = errors or {}
        errors[#errors + 1] = {
          errcode = fault.INVALID_NAME,
          errmsg = "invalid path: " .. path,
          path = path
        }
      end
    end
  end
  if authorized then
    data, errors = dm.set(req.data)
  end
  if not data then
    local response = {}
    for _, error in ipairs(errors) do
      response[#response + 1] = { errorcode = error.errcode, errormessage = error.errmsg, path = error.path }
    end
    return nil, response
  end
  return true
end

local function apply(_, req)
  if req.data ~= true then
    return error_response(fault.INVALID_ARGUMENTS, "invalid data")
  end
  local data, errmsg, errcode = dm.apply()
  if not data then
    return error_response(errcode, errmsg)
  end
  return true
end

local function getNextLevel(role, req)
  local path = req.data
  -- note: authorization is only done on request paths, not on
  -- response paths!
  if (type(path) == "string" or istainted(path)) and
     not role:authorize_path(path) then
    return error_response(fault.INVALID_NAME, "invalid path: " .. path)
  end
  local data, errmsg, errcode = dm.getPN(path, true)
  if not data then
    return error_response(errcode, errmsg)
  end
  -- remove empty 'name' fields
  for _, entry in ipairs(data) do
    if entry.name == "" then
      entry.name = nil
    end
  end
  return data
end

local function add(role, req)
  if type(req.data) ~= "table" then
    return error_response(fault.INVALID_ARGUMENTS, "invalid data")
  end
  -- note: authorization is only done on request paths, not on
  -- response paths!
  local path = req.data.path
  if  (type(path) == "string" or istainted(path)) and
     not role:authorize_path(path) then
    return error_response(fault.INVALID_NAME, "invalid path: " .. path)
  end
  local data, errmsg, errcode = dm.add(path, req.data.name)
  if not data then
    return error_response(errcode, errmsg)
  end
  return data
end

local function delete(role, req)
  local path = req.data
  -- note: authorization is only done on request paths, not on
  -- response paths!
  if (type(path) == "string" or istainted(path)) and
     not role:authorize_path(path) then
    return error_response(fault.INVALID_NAME, "invalid path: " .. path)
  end
  local data, errmsg, errcode = dm.del(path)
  if not data then
    return error_response(errcode, errmsg)
  end
  return data
end

local commands = {
  get = get,
  set = set,
  apply = apply,
  getNextLevel = getNextLevel,
  add = add,
  delete = delete,
  __index = function()
    return unknown
  end
}
setmetatable(commands, commands)

local M = {}

---
-- Process the request under the authorization of the given role.
-- @tparam Role role The role object to use for authorization checks. Must not be `nil`.
function M.process(role)
  ngx.header.content_type = "application/json"
  -- first read the data
  local data, err = get_data()
  if data then
    -- decode the JSON request
    local _
    data, _, err = json.decode(data, 1, nil, nil)
    if not data then
      ngx.log(ngx.ERR, "could not parse request as JSON: ", err)
      _, err = error_response(fault.INVALID_ARGUMENTS, err)
    end
  end
  local command
  if data then
    -- process the request
    command = data.command
    local handler = commands[command]
    if not role:authorize_command(command) then
      -- this command is not allowed; pretend we don't know it
      handler = unknown
    end
    data, err = handler(role, data)
  end
  -- encode the response
  if not data then
    data = { command = command, error = err }
  else
    data = { command = command, response = data }
  end
  local output_buffer = {}
  -- TODO: remove the indent = true
  json.encode(data, { indent = true, buffer = output_buffer })
  ngx.print(output_buffer)
end

return M
