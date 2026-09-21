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
local debug = require("webservice.webapi_debug")
local ngx = ngx
local type, unpack, ipairs, pairs = type, unpack, ipairs, pairs
local remove = table.remove
local istainted = string.istainted

local function error_response(errorcode, errormessage)
  return nil, { errorcode = errorcode, errormessage = errormessage }
end

local function read_request_data()
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

local function remove_blacklisted_parameters(role, params)
  if role:is_blacklist() then
    -- iterate backwards to allow safe removal
    for i=#params, 1, -1 do
      -- the params are either coming from a get request that has param
      -- set to the parameter name,
      -- or from a getParameterNames request that has name set as the
      -- path name for the next level.
      -- the two are mutually exclusive and we have to handle both.
      local nextLevel = params[i].param or params[i].name
      local path = params[i].path .. nextLevel
      if not role:authorize_path(path) then
        remove(params, i)
      end
    end
  end
end

local function get(role, req)
  if type(req.data) ~= "table" then
    return error_response(fault.INVALID_ARGUMENTS, "invalid data")
  end
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
  remove_blacklisted_parameters(role, data)
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

local function do_apply()
  local data, errmsg, errcode = dm.apply()
  if not data then
    return error_response(errcode, errmsg)
  end
  return true
end

local function apply(_, req)
  if req.data ~= true then
    return error_response(fault.INVALID_ARGUMENTS, "invalid data")
  end
  return do_apply()
end

local function setAndApply(role, req)
  local set_ok, err =  set(role, req)
  if not set_ok then
    return nil, err
  end
  return do_apply()
end

local function getNextLevel(role, req)
  local path = req.data
  if (type(path) == "string" or istainted(path)) and
     not role:authorize_path(path) then
    return error_response(fault.INVALID_NAME, "invalid path: " .. path)
  end
  local data, errmsg, errcode = dm.getPN(path, true)
  if not data then
    return error_response(errcode, errmsg)
  end
  remove_blacklisted_parameters(role, data)
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
  setAndApply = setAndApply,
  getNextLevel = getNextLevel,
  add = add,
  delete = delete,
  __index = function()
    return unknown
  end
}
setmetatable(commands, commands)

local compoundCommands = {
  setAndApply = {"set", "apply"}
}

local function receive_request()
  local request
  local raw_data, err = read_request_data()
  if raw_data then
    -- decode the JSON request
    local _
    request, _, err = json.decode(raw_data, 1, nil, nil)
    if not request then
      ngx.log(ngx.ERR, "could not parse request as JSON: ", err)
      _, err = error_response(fault.INVALID_ARGUMENTS, err)
    end
  end
  debug.logJson(request)
  return request, err
end

local function send_response(command, response, err)
  local response_json
  if not response then
    response_json = { command = command, error = err }
  else
    response_json = { command = command, response = response }
  end
  local output_buffer = {}
  -- TODO: remove the indent = true
  json.encode(response_json, { indent = true, buffer = output_buffer })
  debug.logJson(response_json)
  ngx.print(output_buffer)
end

local function authorize_command(role, command)
  if role:authorize_command(command) then
    return true
  end
  local compound = compoundCommands[command]
  if not compound then
    return false
  end
  for _, cmd in ipairs(compound) do
    if not role:authorize_command(cmd) then
      return false
    end
  end
  return true
end

local function command_handler(role, command)
  local handler = commands[command]
  if not authorize_command(role, command) then
    -- this command is not allowed; pretend we don't know it
    handler = unknown
  end
  return handler
end

local function process_request(role, request, token)
  local command = request.command
  local handler = command_handler(role, command)
  local response, err = handler(role, request, token)
  
  return command, response, err
end

local M = {}

---
-- Process the request under the authorization of the given role.
-- @tparam Role role The role object to use for authorization checks. Must not be `nil`.
-- @tparam string token The token for the request. May be `nil`. This is passed verbatim to
--   the handler function.
function M.process(role, token)
  ngx.header.content_type = "application/json"
  local command, response
  
  local request, err = receive_request()
  if request then
    command, response, err = process_request(role, request, token)
  end
  
  send_response(command, response, err)
end

--- Add a new command to the webservice
-- @string command the command name
-- @tparam [function] the handler function.
-- @returns true if command successfully added
-- @error an error message (eg for a duplicate name)
function M.add_command(command, handler)
  if commands[command] == unknown then
    commands[command] = handler
    return true
  end
  return nil, "duplicate command"
end

return M
