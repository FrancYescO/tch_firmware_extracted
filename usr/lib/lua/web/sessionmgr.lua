local setmetatable, pairs, ipairs, tonumber, require, type = setmetatable, pairs, ipairs, tonumber, require, type
local ngx, tostring = ngx, tostring
local dm = require("datamodel")
local srp = require("srp")
local printf = require("web.web").printf
local get_cookies = require("web.web").get_cookies
local untaint = string.untaint
local posix = require("tch.posix")
local clock_gettime = posix.clock_gettime
local CLOCK_MONOTONIC = posix.CLOCK_MONOTONIC
local Session = require("web.session")

local SessionMgr = {}
SessionMgr.__index = SessionMgr

local function newSessionTracker()
  return {
    count = 0,
    ipcount = {},
  }
end

--- did we reach the session limit
-- @param self (SessionMgr) The session manager
-- @param remoteIP (string) The remote IP address
-- @return true if the overall session limit is reached or the
--   per IP limit for the given IP address is reached.
--   Otherwise returns nil.
local function sessionLimitReached(self, remoteIP)
  if self.maxsessions<=self._session_tracker.count then
    return true
  end
  local ipCount = self._session_tracker.ipcount[remoteIP] or 0
  if self.maxsessions_per_ip<=ipCount then
    return true
  end
end

--- adjust the total number of sessions for the given ip
-- @param self (SessionMgr) The session manager
-- @param remoteIP (string) the IP address
-- @param delta (int) the amount to adjust
local function adjustIPCount(self, remoteIP, delta)
  local ipcount = self._session_tracker.ipcount
  if remoteIP then
    ipcount[remoteIP] = (ipcount[remoteIP] or 0) + delta
  end
end

--- add a session to a session manager
-- @param self (SessionMgr) The session manager
-- @param session The session to add
-- @param sessionID the sessionID to use
local function addSession(self, session, sessionID)
  if not self.sessions[sessionID] then
    self.sessions[sessionID] = session
    self._session_tracker.count = self._session_tracker.count+1
    adjustIPCount(self, session.remoteIP, 1)
  end
end

--- remove a session from a session manager
-- @param self (SessionMgr) The session manager
-- @param sessionID The session ID of the session to remove
local function removeSession(self, sessionID)
  if self.sessions[sessionID] then
    local remoteIP = self.sessions[sessionID].remoteIP
    self.sessions[sessionID] = nil
    self._session_tracker.count = self._session_tracker.count-1
    adjustIPCount(self, remoteIP, -1)
  end
end

--- check if the session is expired and remove if it is
-- @param self The session manager
-- @param session The session to check
-- @param sessionID The sessionID of the session
-- @param now (optional) the current time (from CLOCK_MONOTONIC)
-- @param timeout (optional) the timeout (defaults to self.timeout)
-- @return true if expired and nil otherwise
-- If the session is expired it is removed from the session managers list of
-- sessions.
local function sessionExpired(self, session, sessionID, now, timeout)
  now = now or clock_gettime(CLOCK_MONOTONIC)
  timeout = timeout or self.timeout
  local timeLeft = (session.timestamp + timeout) - now
  if timeLeft <=0 then
    removeSession(self, sessionID)
    return true, 0
  end
  return false, timeLeft
end

--- Verify a given session is still valid.
-- @param self The session manager that needs to verify the session.
-- @param sessionID The session ID of the session that needs verification.
-- @param remoteIP The IP address of the originator of the request.
-- @return True if the session with given session ID is valid, false otherwise.
local function verifySession(self, sessionID, remoteIP)
  if sessionID and self.sessions[sessionID] then
    -- SessionID corresponds to a known session.
    -- Check if the IP hasn't changed or the session timed out.
    local session = self.sessions[sessionID]
    if session.remoteIP ~= remoteIP then
      return false
    end
    if not sessionExpired(self, session, sessionID) then
      return true
    end
  end
  return false
end

--- Retrieve the real session given its proxy.
-- @param self The session manager that should contain the session.
-- @param proxy The proxy of the session
-- @return The real session for the proxy or nil if not found.
local function retrieveSessionFromProxy(self, proxy)
  for _,v in pairs(self.sessions) do
    if v.proxy == proxy then
      return v
    end
  end
  return nil
end

--- Check if a request for the given resource can be authorized or not.
-- @param self The session manager that needs to authorize the request.
-- @param session The session in which the request needs to be authorized.
-- @param resource The resource that is being requested.
-- @return True if the request is allowed in the given session. Otherwise
--         false + appropriate HTTP status code is returned (404, 403, ...).
function SessionMgr:authorizeRequest(session, resource)
  resource = untaint(resource)
  -- if the configured assistant is not active then no request is authorized
  if self.assistant and not self.assistant:enabled() then
    return false, ngx.HTTP_NOT_FOUND
  end
  -- access to authpath, passpath and loginpath is always allowed
  if resource == self.authpath or resource == self.passpath or resource == self.loginpath then
    return true
  end
  -- do we know the requested resource?
  local ruleset = self.ruleset[resource]
  if not ruleset then
    return false, ngx.HTTP_NOT_FOUND
  end
  -- is the user's role allowed to access this resource?
  local role = session:getrole()
  if not ruleset[role] then
    return false, ngx.HTTP_FORBIDDEN
  end
  -- OK, you can proceed
  return true
end

--- Check if the current request has a valid session and if it
-- is an authorized request.
function SessionMgr:checkrequest()
  local remoteIP = untaint(ngx.var.remote_addr)
  local session
  -- Find session based on sessionID in cookie.
  -- Note that we must be able to handle multiple session cookies being sent
  -- to us. This could happen when multiple session mgrs are configured.
  local sessionID = untaint(get_cookies()["sessionID"])
  if type(sessionID) == "table" then
    local found = false
    for _, ID in ipairs(sessionID) do
      if self.sessions[ID] then
        sessionID = ID
        found = true
        break
      end
    end
    if not found then
      sessionID = nil
    end
  end
  if not verifySession(self, sessionID, remoteIP) then
    -- No valid session, create new one.
    if sessionLimitReached(self, remoteIP) then
      -- the maximum number of sessions has been exceeded.
      ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
    end
    sessionID = nil
    -- Loop should only occur once and is here to avoid session ID clashes.
    while not sessionID or self.sessions[sessionID] do
      session = Session.new(remoteIP, self)
      sessionID = session.sessionid
    end
    addSession(self, session, sessionID)
    -- Set the cookie.
    local cookie = "sessionID="..sessionID.."; Path="..self["cookiepath"].."; HttpOnly"
    if self.secure_cookie == "1" then
      cookie = cookie .. "; Secure"
    end
    ngx.header['Set-Cookie'] = cookie
  else
    -- The session is verified and valid.
    session = self.sessions[sessionID]
    session.timestamp = clock_gettime(CLOCK_MONOTONIC)
    if self.assistant then
      self.assistant:activity()
    end
  end
  -- Session verified or renewed; check that request is allowed.
  local rc, resp_code = self:authorizeRequest(session, ngx.var.uri)
  if not rc then
    -- Not found.
    if resp_code == ngx.HTTP_NOT_FOUND then
      ngx.exit(resp_code)
    end
    ngx.log(ngx.ERR, "Unauthorized request")
    -- Not authorized; show the login page.
    ngx.exec(self.loginpath)
  end

  -- store session object in nginx request context so
  -- it can be accessed by content phase code (e.g. Lua Pages)
  ngx.ctx.session = session.proxy
end

-- Handle authentication requests according to the SRP protocol.
-- If the request is an authentication request then we handle
-- it completely and we don't continue to the content phase.
-- We implement SRP-6a, see http://srp.stanford.edu/design.html
-- In particular the flow is as follows:
-- - We receive the username 'I' and ephemeral value 'A' from the client.
-- - We instantiate a new SRP verifier object and return a salt 's'
--   and our ephemeral value 'B' to the client.
-- - We receive the value 'M' from the client.
-- - If that value matches our value then we send our 'M2' value.
--   Otherwise authentication failed.
-- The 'change password' functionality is implemented as an extension
-- of authentication (but on a different location) since you must first
-- authenticate before you are allowed to change your password. After
-- having completed the authentication a flag is set on the session.
-- When a third request is sent with the new salt and verifier the user
-- configuration is updated.
function SessionMgr:handleAuth()
  -- check if it's an authentication request
  local uri = ngx.var.uri
  if uri ~= self.authpath and uri ~= self.passpath then
    return
  end
  -- only POST is allowed
  if ngx.req.get_method() ~= "POST" then
    ngx.exit(ngx.HTTP_FORBIDDEN)  -- doesn't return
  end
  -- our responses are JSON
  ngx.header.content_type = "application/json"
  local post_args = ngx.req.get_post_args()
  local session = retrieveSessionFromProxy(self, ngx.ctx.session)
  local I, A, M = untaint(post_args.I), untaint(post_args.A), untaint(post_args.M)
  if I and A and session then
    -- first step in SRP
    if session.verifier then
      session.verifier:destroy()
      session.verifier = nil
    end
    -- A new authentication flow has started so you're
    -- not allowed to change your password until authenticated.
    -- Note that this resets the flag even when a new regular
    -- authentication is started.
    session.changeAllowed = nil
    local user = self.users[I]
    if not user then
      -- TODO: shouldn't reveal that the username is unknown; instead
      --       we should generate a fake salt and B and in the second
      --       step simply report that authentication failed
      ngx.print('{ "error":"failed" }')
    else
      -- return salt and B
      local B
      session.verifier, B = srp.Verifier(I, user.srp_salt, user.srp_verifier, A)
      printf('{ "s":"%s", "B":"%s" }', user.srp_salt, B)
    end
    ngx.exit(ngx.HTTP_OK)  -- doesn't return
  end
  if M and session then
    -- second step in SRP
    local verifier = session.verifier
    if not verifier then
      -- if the first step wasn't performed return an error
      ngx.exit(ngx.HTTP_BAD_REQUEST)
    end
    local M2, errmsg = verifier:verify(M)
    if M2 then
      -- user's M value is OK, we're authenticated
      -- update username and role of session
      local user = self.users[verifier:username()]
      session.user = user
      -- if authentication happened via the 'change password'
      -- location then you're allowed to change the password
      if uri == self.passpath then
        session.changeAllowed = true
      end
      -- now send our proof
      printf('{ "M":"%s" }', M2)
    else
      printf('{ "error":"%s" }', errmsg or "failed")
    end
    -- Destroy verifier; it has done its job.
    -- Also, it shouldn't be possible to send another M value,
    -- you have to start again from step 1.
    verifier:destroy()
    session.verifier = nil
    ngx.exit(ngx.HTTP_OK)  -- doesn't return
  end
  local salt, verifier = post_args.salt, post_args.verifier
  if session and session.changeAllowed and salt and verifier then
    session.changeAllowed = nil
    -- Password change is allowed, update with given values.
    local rc, err = self.sessioncontrol.changePassword(session.user, salt, verifier)
    if rc then
      printf('{ "success":"true" }')
      ngx.exit(ngx.HTTP_OK)  -- doesn't return
    end
    ngx.log(ngx.ERR, "user '", session.user.name, "' could not be updated: ", err or "(unknown reason)")
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  -- no auth related parameters in request so return an error
  ngx.exit(ngx.HTTP_BAD_REQUEST)  -- doesn't return
end

--- Clean up all timed out sessions.
-- @return number of remaining sessions and time until next sessions expires
-- if the number of remaining sections is zero the time until the next section
-- expires is undefined.
function SessionMgr:cleanup()
  local timeout = self.timeout
  local remaining = 0
  local timeUntilNext
  local now = clock_gettime(CLOCK_MONOTONIC)
  for sid, session in pairs(self.sessions) do
    local expired, timeLeft = sessionExpired(self, session, sid, now, timeout)
    if not expired then
      remaining = remaining + 1
      if (not timeUntilNext) or (timeLeft<timeUntilNext) then
        timeUntilNext = timeLeft
      end
    end
  end
  return remaining, timeUntilNext
end

--NOTE: The user has been created in uci.web.user.@., we just need to add it to this session manager.
--Have session control reload the user.
--- Adds a user to an existing user manager. It assumes the user was created in the datamodel and we just need to add it to the users property
-- @param instancename the instance name of the user that we must add
-- @return success, msg
function SessionMgr:addUser(instancename)
  self.sessioncontrol.reloadUsers()
  local user = self.sessioncontrol.getuser(instancename)
  if not user or not user.name then
    return nil, "Invalid user instance: "..tostring(instancename)
  end
  if self.users[user.name] then
    return nil, "A user with this username already exists"
  else
    local userspath = "uci.web.sessionmgr.@" .. self.name .. ".users."
    local index, msg = dm.add(userspath)
    if index then
      local userpath = userspath .. "@" .. index .. ".value"
      local result = dm.set(userpath, instancename)
      if result then
        self.users[user.name] = user
        return true
      else
        dm.del(userspath .. "@" .. index .. ".") -- try to clean up
        return nil, "Unable to set user's value"
      end
    else
      return nil, "Unable to add a user to list of allowed users"
    end
  end
end

--- Deletes a user from an existing manager config. Does not delete the user config!
-- @param instancename the name of the instance that must be removed
function SessionMgr:delUser(instancename)
  local name
  for _,v in pairs(self.users) do
    if v.sectionname == instancename then
      name = v.name
    end
  end
  if name then
    local userspath = "uci.web.sessionmgr.@" .. self.name .. ".users."
    local results = dm.get(userspath)
    if results then
      for _,v in ipairs(results) do
        if v.value == instancename then
          local result = dm.del(v.path)
          if result then
            self.users[name] = nil
            return true
          else
            return nil, "Error while removing user"
          end
        end
      end
      return nil, "Could not find user in datamodel"
    else
      return nil, "Users list does not exist"
    end
  else
    return nil, "Could not find user in session manager"
  end
end

function SessionMgr:reloadUsers()
  local sections = {}
  for _, user in pairs(self.users) do
    sections[#sections+1] = user.sectionname
  end
  local users = {}
  for _, section in ipairs(sections) do
    local user = self.sessioncontrol.getuser(section)
    if user then
      users[user.name] = user
    end
  end
  self.users = users
end

--- get the external address (as seen by the user) for this manager
-- \returns ipaddr, port either can be nil to tell the external port is the
--          same as the internal one
function SessionMgr:getExternalAddress()
  local assistant = self.assistant
  if assistant and assistant:enabled() then
    return assistant:getExternalAddress()
  else
    return nil, self.public_port
  end
end

local function verify_sessionlimit_value(value, default)
    local max = tonumber(value) or default
    if max > 0 then
      return max
    elseif max == -1 then
      return math.huge
    end
    return default
end

local config_verifiers = {
  ruleset = function(self, key, value, sessioncontrol)
    local ruleset = sessioncontrol.getruleset(value)
    if not ruleset then
      ngx.log(ngx.ERR, "no config found for ruleset ", value)
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    -- ruleset is already expanded by session control.
    self.ruleset = ruleset
  end,
  users = function(self, key, value, sessioncontrol)
    for internal_username in pairs(value) do
      -- Use reference to user table from sessioncontrol
      local userconfig = sessioncontrol.getuser(internal_username)
      if not userconfig then
        ngx.log(ngx.ERR, "no config found for user ", internal_username)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
      end
      self.users[userconfig.name] = userconfig
    end
  end,
  default_user = function(self, key, value, sessioncontrol)
    if value ~= "" then
      local userconfig = sessioncontrol.getuser(value)
      if not userconfig then
        ngx.log(ngx.ERR, "no config found for default user ", value)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
      end
      self[key] = userconfig
    end
  end,
  maxsessions = function(self, key, value)
    self.maxsessions = verify_sessionlimit_value(value, self.maxsessions)
  end,
  maxsessions_per_ip = function(self, key, value)
    self.maxsessions_per_ip = verify_sessionlimit_value(value, self.maxsessions_per_ip)
  end,

  _default = function(self, key, value)
    -- Options that are not set in UCI result in empty string
    -- as value. For these unset options we want the option to
    -- be completely absent in 'self' so we can check for it
    -- with a simple 'if self.foo then' instead of having to
    -- compare it with empty string, which can be forgotten.
    if value ~= "" then
      self[key] = value
    end
  end
}

--- Helper function to parse a session manager's configuration table.
local function parse_mgr_config(self, mgr_config)
  if type(mgr_config) ~= "table" then
    return
  end
  self.ruleset = nil
  self.users = {}
  local sessioncontrol = self.sessioncontrol
  for k, v in pairs(mgr_config) do
    local verifier = config_verifiers[k] or config_verifiers._default
    verifier(self, k, v, sessioncontrol)
  end
  -- check that the default user (if any) is in the list of users
  -- that are allowed in this session mgr
  if self.default_user and not self.users[self.default_user.name] then
    ngx.log(ngx.ERR, "user list does not contain default user ", mgr_config.default_user)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  --TODO: Do we need to verify the sessions? Invalidate if needed?
end

function SessionMgr:reloadConfig(mgr_config)
  parse_mgr_config(self, mgr_config)
end

function SessionMgr:setDefaultUser(user)
  local value = user and user.sectionname or ""
  local rc, errors = dm.set("uci.web.sessionmgr.@" .. self.name .. ".default_user", value)
  if not rc then
    return nil, errors[1].errmsg
  end
  self.default_user = user
  return true
end

local M = {}

function M.new(mgr_name, mgr_config, sessioncontrol)
  local new_mgr = setmetatable(
    {
      name = mgr_name,
      sessioncontrol = sessioncontrol,
      sessions = {},
      users = {},
      ruleset = {},
      maxsessions = 50,
      maxsessions_per_ip = 10,
    },
    SessionMgr)
  parse_mgr_config(new_mgr, mgr_config)
  -- some sanity checks on the config values
  -- the timeout must be a number > 0
  local timeout = tonumber(new_mgr.timeout)
  if not timeout or timeout <= 0 then
    ngx.log(ngx.ERR, "invalid timeout for sessionmgr ", mgr_name)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  -- config gives timeout in minutes; internally we want it in seconds
  new_mgr.timeout = timeout * 60
  if (not new_mgr.default_user or new_mgr.default_user == "") and (not new_mgr.loginpath or new_mgr.loginpath == "") then
    ngx.log(ngx.ERR, "must set the login page for sessionmgr ", mgr_name)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  -- cookiepath, authpath and passpath must be non-empty
  if not new_mgr.cookiepath or not new_mgr.authpath or not new_mgr.passpath or new_mgr.cookiepath == "" or new_mgr.authpath == "" or new_mgr.passpath == "" then
    ngx.log(ngx.ERR, "cookiepath, authpath or passpath not given for sessionmgr ", mgr_name)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  new_mgr._session_tracker = newSessionTracker()
  return new_mgr
end

return M
