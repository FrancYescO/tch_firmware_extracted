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
-- Access control module for the Web Service API, based on tokens.
--
-- This module implements an authentication mechanism based on a token
-- that must be sent in a HTTP header `X-tch-token` together with the
-- web service request. After authentication a Role object is returned
-- that must be used when processing the request to do further
-- authorization checks (see @{webservice.api} module).
--
-- The tokens and associated roles are configured in UCI. This configuration
-- is loaded when the first request is received. If the configuration is
-- updated the module must be triggered to reload the config, see @{reload_config}.
-- @module webservice.accesscontrol_token
-- @usage
-- content_by_lua '
--   local role = require("webservice.accesscontrol_token").authenticate()
--   require("webservice.api").process(role)
-- ';

local ngx = ngx
local dm = require("datamodel")
local match, untaint = string.match, string.untaint
local pairs, ipairs, next = pairs, ipairs, next

-- Role object
local Role = {}
Role.__index = Role

---
-- Check if the given role is authorized to perform the given command.
-- @string command The command to check.
-- @treturn boolean Whether the command is authorized according to the config.
function Role:authorize_command(command)
  if not self.allowed_commands[command] then
    return false
  end
  return true
end

---
-- Check if the given role is authorized to access the given path.
-- @string path A (possibly tainted) string containing the path to check.
-- @treturn boolean Whether the path is authorized according to the config.
function Role:authorize_path(path)
  for pattern in pairs(self.allowed_paths) do
    if match(path, pattern) then
      return true
    end
  end
  return false
end

-- Read our config from UCI and store it in a
-- suitable format for later use.
-- Returns (possibly empty) config
local function read_config()
  local config = { users = {}, roles = {} }
  local data, errmsg = dm.get("uci.webservice.")
  if not data then
    ngx.log(ngx.ERR, "failed to retrieve config: ", errmsg)
    return config
  end
  for _, v in ipairs(data) do
    local sectiontype, sectionname, listparam = match(v.path, "uci%.webservice%.([^%.]+)%.@([^%.]+)%.([^%.]*)")
    if sectiontype == "user" then
      local user = config.users[sectionname]
      if not user then
        user = {}
        config.users[sectionname] = user
      end
      user[v.param] = untaint(v.value)
    elseif sectiontype == "role" then
      local role = config.roles[sectionname]
      if not role then
        role = setmetatable({}, Role)
        config.roles[sectionname] = role
      end
      if listparam ~= "" then  -- all parameters of a role are currently lists
        local param = role[listparam]
        if not param then
          param = {}
          role[listparam] = param
        end
        param[untaint(v.value)] = true
      end
    end
  end
  local users = {}
  -- sanity checks on roles
  for role, params in pairs(config.roles) do
    if not params.allowed_paths or not next(params.allowed_paths) then
      ngx.log(ngx.ERR, "no allowed_paths for role ", role)
      config.roles[role] = nil
    end
    if not params.allowed_commands or not next(params.allowed_commands) then
      ngx.log(ngx.ERR, "no allowed_commands for role ", role)
      config.roles[role] = nil
    end
  end
  -- sanity checks on users
  for username, values in pairs(config.users) do
    local error_found = false
    -- check that a token is given
    if not values.token or values.token == "" then
      error_found = true
      ngx.log(ngx.ERR, "no token given for user ", username)
    end
    -- check that role is valid
    if not config.roles[values.role] then
      error_found = true
      ngx.log(ngx.ERR, "invalid role ", values.role or "(nil)", " given for user ", username)
    end
    if not error_found then
      users[values.token] = config.roles[values.role]
    end
  end
  config.users = users
  return config
end

-- load config when this module is loaded, typically
-- on first time a request is received
local s_config = read_config()

local M = {}

---
-- Authenticate the request.
--
-- A number of checks will be done. If a check fails the request will
-- be terminated with a HTTP error.
-- @treturn Role If authentication is successful the associated role is returned.
--   This object can be used for further authorization checks. See
--   @{webservice.api} module.
function M.authenticate()
  -- request must come over HTTPS
  if ngx.var.https ~= "on" then
    ngx.log(ngx.WARN, "request not over HTTPS")
    return ngx.exit(ngx.HTTP_FORBIDDEN)
  end
  -- we only allow HTTP POST
  if ngx.var.request_method ~= "POST" then
    ngx.log(ngx.WARN, "not POST request")
    ngx.header.allow = "POST"
    return ngx.exit(ngx.HTTP_NOT_ALLOWED)
  end
  -- check for the presence of a specific header carrying the authentication token
  local token = untaint(ngx.var.http_x_tch_token)
  if not token then
    ngx.log(ngx.WARN, "request without token")
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end
  -- check if it's a known token and if so find the associated role info
  local role = s_config.users[token]
  if not role then
    ngx.log(ngx.WARN, "request with invalid token ", token)
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end
  return role
end

---
-- Reload the config.
--
-- If the UCI config has changed this function must be called to
-- reread the configuration and apply it.
function M.reload_config()
  ngx.log(ngx.INFO, "reloading config")
  s_config = read_config()
end

return M
