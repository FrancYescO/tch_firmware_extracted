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
local srp = require("srp")
local match, untaint = string.match, string.untaint
local pairs, ipairs, next = pairs, ipairs, next
local setmetatable = setmetatable
local type = type

local Role = {}
Role.__index = Role

---
-- Check if the given role has a whitelist configuration.
-- @treturn boolean Whether the role has a whitelist configuration.
function Role:is_whitelist()
  return self.allowed_paths~=nil
end

---
-- Check if the given role has a blacklist configuration.
-- @treturn boolean Whether the role has a blacklist configuration.
function Role:is_blacklist()
  return self.disallowed_paths~=nil
end

---
-- Check if the given role is authorized to perform the given command.
-- @string command The command to check.
-- @treturn boolean Whether the command is authorized according to the config.
function Role:authorize_command(command)
  return self.allowed_commands[command]~=nil
end

local function matches_one_of(patterns, value)
  for pattern in pairs(patterns) do
    if match(value, pattern) then
      return true
    end
  end
  return false
end

---
-- Check if the given role is authorized to access the given path.
-- @string path A (possibly tainted) string containing the path to check.
-- @treturn boolean Whether the path is authorized according to the config.
function Role:authorize_path(path)
  if self:is_whitelist() then
    return matches_one_of(self.allowed_paths, path)
  else
    return not matches_one_of(self.disallowed_paths, path)
  end
end

local function authenticate_literal_token(token, user)
  return token == user.token
end

local User = {}
User.__index = User

function User:authenticate(token)
  local authenticator = self.authenticator
  return authenticator(token, self)
end

local Config = {
  _authenticators = {}
}
Config.__index = Config

function Config.add_authenticator(name, authenticator)
  local auth = Config._authenticators[name]
  if not auth then
    Config._authenticators[name] = authenticator
    return Config._config~=nil
  end
  return nil, "Duplicate authenticator"
end

function Config:role_for_token(token)
  for _, user in ipairs(self.users) do
    local auth, err, err_token = user:authenticate(token)
    if auth then
      return user.role
    elseif err then
      return nil, err, err_token
    end
  end
end

local function authenticate_web_user_token(token, user)
  -- fetch SRP parameters of user
  local data, errmsg = dm.get("uci.web.user.@" .. user.token .. ".srp_salt",
                              "uci.web.user.@" .. user.token .. ".srp_verifier",
                              "uci.web.user.@" .. user.token .. ".name")
  if not data then
    ngx.log(ngx.ERR, "failed to retrieve web user credentials: ", errmsg)
    return
  end
  local I, s, v
  for _, item in ipairs(data) do
    if item.param == "srp_salt" then
      s = untaint(item.value)
    elseif item.param == "srp_verifier" then
      v = untaint(item.value)
    elseif item.param == "name" then
      I = untaint(item.value)
    end
  end
  -- check cache
  if user.verifier == v then
    -- SRP verifier is still the same; if token matches we can
    -- consider the request as authenticated
    if token == user.accepted_token then
      return user.role
    end
  else
    -- verifier doesn't match; cache it for later
    user.verifier = v
    -- also reset accepted token
    user.accepted_token = nil
  end
  -- do SRP handshake
  local srpUser, A = srp.User(I, token)
  local Verifier, B
  if srpUser then
    Verifier, B = srp.Verifier(I, s, v, A)
  end
  local H_AMK
  if Verifier then
    local M = srpUser:get_M(s, B)
    if M then
      H_AMK = Verifier:verify(M)
    end
  end
  local authenticated = false
  if H_AMK and srpUser:verify(H_AMK) then
    -- authenticated; store accepted token for faster checking later
    authenticated = true
    user.accepted_token = token
  end
  if srpUser then
    srpUser:destroy()
  end
  if Verifier then
    Verifier:destroy()
  end
  return authenticated
end


local function log_error(...)
  ngx.log(ngx.ERR, ...)
end

local function load_config_from_dm()
  local config = { user = {}, role = {} }
  local params, errmsg = dm.get("uci.webservice.")
  if not params then
    log_error("failed to retrieve config: ", errmsg)
    return {users={}, roles={}}
  end
  for _, v in ipairs(params) do
    local sectiontype, sectionname, listparam = match(v.path, "uci%.webservice%.([^%.]+)%.@([^%.]+)%.([^%.]*)")
    sectiontype = config[sectiontype]
    if sectiontype then
      local section = sectiontype[sectionname]
      if not section then
        section = { _name = sectionname }
        sectiontype[sectionname] = section
      end
      if listparam~="" then
        local param = section[listparam]
        if not param then
          param = {}
          section[listparam] = param
        end
        param[untaint(v.value)] = true
      else
        section[v.param] = untaint(v.value)
      end
    end
  end
  return { users=config.user, roles=config.role}
end

local function is_list(x)
  return type(x)=="table"
end

local function create_role(role)
  if not is_list(role.allowed_commands) then
    log_error("no allowed_commands for role ", role._name)
  elseif is_list(role.allowed_paths) and is_list(role.disallowed_paths) then
    log_error("allowed_paths and disallowed_paths can not be mixed for role ", role._name)
  elseif not is_list(role.allowed_paths) and not is_list(role.disallowed_paths) then
    log_error("no allowed_paths or disallowed_paths for role ", role._name)
  else
    return setmetatable(role, Role)
  end
end

local function sanity_check_roles(roles)
  local valid_roles = {}
  for role, params in pairs(roles) do
    valid_roles[role] = create_role(params)
  end
  return valid_roles
end


local function create_user(user, roles)
  if not user.token or user.token == "" then
    return log_error("no token given for user ", user._name)
  end
  user.token_is = (user.token_is ~= "") and user.token_is or "literal"
  local authenticator = Config._authenticators[user.token_is]
  if not authenticator then
    return log_error("invalid 'token_is' value ", user.token_is)
  end
  local role = roles[user.role]
  if not role then
    return log_error("invalid role ", user.role or "(nil)", " given for user ", user._name)
  end
  user.role = role
  user.authenticator = authenticator
  return setmetatable(user, User)
end

local function sanity_check_users(users, roles)
  local valid_users = {}
  for username, values in pairs(users) do
    valid_users[#valid_users+1] = create_user(values, roles)
  end
  return valid_users
end

-- Read our config from UCI and store it in a
-- suitable format for later use.
-- Returns (possibly empty) config
local function read_config()
  local config = load_config_from_dm()
  local roles = sanity_check_roles(config.roles)
  local users = sanity_check_users(config.users, roles)
  return setmetatable({
    roles = roles,
    users = users
  }, Config)
end

function Config.current()
  local config = Config._config
  if not config then
     config = read_config()
     Config._config = config
  end
  return config
end

function Config.reload()
  Config._config = nil
  return Config.current()
end

local function is_https_post()
  if ngx.var.https ~= "on" then
    ngx.log(ngx.WARN, "request not over HTTPS")
    return false, ngx.HTTP_FORBIDDEN
  elseif ngx.var.request_method ~= "POST" then
    ngx.log(ngx.WARN, "not POST request")
    ngx.header.allow = "POST"
    return false, ngx.HTTP_NOT_ALLOWED
  end
  return true
end

local function find_token(token)
  token = token or untaint(ngx.var.http_x_tch_token)
  if not token then
    ngx.log(ngx.WARN, "request without token")
    return nil, ngx.HTTP_FORBIDDEN
  end
  return token
end

local M = {}

---
-- Authenticate the request.
--
-- A number of checks will be done. If a check fails the request will
-- be terminated with a HTTP error.
-- @string token the token to authenticate. If nil use the x_tch_token header value
-- @treturn Role If authentication is successful the associated role is returned.
--   This object can be used for further authorization checks. See
--   @{webservice.api} module.
function M.authenticate(token)
  local config = Config.current()
  
  local https_post, http_status = is_https_post()
  if not https_post then
    return ngx.exit(http_status)
  end

  token, http_status = find_token(token)
  if not token then
    return ngx.exit(http_status)
  end

  local role, err, err_token = config:role_for_token(token)
  if not role then
    ngx.log(ngx.WARN, err or "request with invalid token ", err_token or token)
    return ngx.exit(ngx.HTTP_FORBIDDEN)
  end
  
  return role, token
end

---
-- Reload the config.
--
-- If the UCI config has changed this function must be called to
-- reread the configuration and apply it.
function M.reload_config()
  ngx.log(ngx.INFO, "reloading config")
  Config.reload()
end

--- Add a (custom) authenticator
-- @string name the name of the authenticator, appears in 'token_is' options of user
-- @tparam [function] authenticator the authenticator function
-- @treturn [boolean] indicates if reload of config is needed
-- @error error message if name was already used
-- 
-- The `authenticator` functions must take two parameters: the token to check and
-- the user object.
-- It must return `true` if the token is correct for the given user. If not it can
-- return either `false` or `nil`.
-- In case it can determine the given token is certainly for the given user, but
-- it is incorrect it can return a custom error message and err token. Bot will be
-- recorded in the log instead of the default log message.
function M.add_authenticator(name, authenticator)
  return Config.add_authenticator(name, authenticator)
end

do -- module init
  Config.add_authenticator("literal", authenticate_literal_token)
  Config.add_authenticator("web_user", authenticate_web_user_token)
end

return M
