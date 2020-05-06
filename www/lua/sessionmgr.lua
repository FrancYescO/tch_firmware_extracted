local setmetatable, pairs, ipairs, tonumber, require, type = setmetatable, pairs, ipairs, tonumber, require, type
local dm = require("datamodel")
local posix = require("tch.posix")
local get_cookies = require("web.web").get_cookies
local action = require("statusservice").action
local Session = require("web.session")
local json = require("dkjson")
local ngx, tostring = ngx, tostring
local untaint = string.untaint
local gsub = string.gsub
local clock_gettime = posix.clock_gettime
local CLOCK_MONOTONIC = posix.CLOCK_MONOTONIC

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
  local persistent = session:retrieve("persistent")
  if persistent == "1" then
    return false, timeout
  end

  now = now or clock_gettime(CLOCK_MONOTONIC)
  timeout = timeout or self.timeout
  local timeLeft = (session.timestamp + timeout) - now
  if timeLeft <=0 then
    removeSession(self, sessionID)
    return true, 0
  end
  return false, timeLeft
end

--- add the session cookie to the HTTP header
-- @param self The session manager
-- @param sessionID the sessionid to set in the cookie
local function setSessionCookie(self, sessionID)
  local cookie = "sessionID="..sessionID.."; Path="..self["cookiepath"].."; HttpOnly"
  if self.secure_cookie == "1" then
    cookie = cookie .. "; Secure"
  end
  ngx.header['Set-Cookie'] = cookie
end

--- check if the session is still the same
-- @param self The session manager
-- @param session The session object to check
-- @param sessionID The sessionID received
-- @return the new sessionid if the session changed and nil otherwise
-- If the session changed then a new cookie will be added to the
-- HTTP headers
-- After a login or logout the user role may change and then the session
-- will change its id but the session manager is not notified.
-- It will check for it here and then update its internal state.
local function sessionChanged(self, session, sessionID)
  -- if the user logs out, the session changes its sessionID
  local newid = session.sessionid
  if newid ~= sessionID then
    -- update the session cookie
    setSessionCookie(self, newid)
    -- update the session list
    self.sessions[newid] = session
    self.sessions[sessionID] = nil
    return newid
  end
end

-- Find sessionID based on cookie headers.
-- Note that we must be able to handle multiple session cookies being sent
-- to us. This could happen when multiple session mgrs are configured.
-- But at most one of those will belong to a session in the given
-- session mgr
local function getSessionIDForRequest(mgr)
  local sessionID = untaint(get_cookies()["sessionID"])
  if type(sessionID) == "table" then
    local found = false
    for _, ID in ipairs(sessionID) do
      if mgr.sessions[ID] then
        sessionID = ID
        found = true
        break
      end
    end
    if not found then
      sessionID = nil
    end
  end
  return sessionID
end

--- Verify a given session is still valid.
-- @param mgr The session manager that needs to verify the session.
-- @param remoteIP The IP address of the originator of the request.
-- @return session and sessionID if valid session found, nil otherwise.
local function verifySession(mgr, remoteIP)
  local sessionID = getSessionIDForRequest(mgr)
  local session = sessionID and mgr.sessions[sessionID]
  if session then
    -- SessionID corresponds to a known session.
    -- Check if the IP hasn't changed or the session timed out.
    if session.remoteIP ~= remoteIP then
      return
    end
    if sessionExpired(mgr, session, sessionID) then
      return
    end
    local newid = sessionChanged(mgr, session, sessionID)
    if newid then
      return session, newid
    end
    return session, sessionID
  end
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

local function login(mgr, session, username)
  local user = mgr.users[username]
  local id = session.sessionid
  session:changeUser(user)
  sessionChanged(mgr, session, id)
end

--- Check if a request for the given resource can be authorized or not.
-- @param self The session manager that needs to authorize the request.
-- @param session The session in which the request needs to be authorized.
-- @param resource The resource that is being requested.
-- @return True if the request is allowed in the given session. Otherwise
--         false + appropriate HTTP status code is returned (404, 403, ...).
function SessionMgr:authorizeRequest(session, resource)
  if not session:isUserAllowedByIP() then
    return false, ngx.HTTP_FORBIDDEN
  end
  -- OK, you can proceed
  return true
end

local function redirectIfNotAuthorized(mgr, session, sessionID)
  local rc, resp_code = mgr:authorizeRequest(session, ngx.var.uri)
  if not rc then
    -- Not found.
    if resp_code == ngx.HTTP_NOT_FOUND then
      ngx.exit(resp_code)
    end
    ngx.log(ngx.ERR, "Unauthorized request")
    -- Not authorized; show the login page.
    -- Make sure this internal redirect uses the new session ID
    -- (if one was created) to avoid allocating a new session.
    -- Don't touch other cookies.
    local new_session_cookie = "sessionID=" .. sessionID
    local cookie_header = untaint(ngx.var.http_cookie)
    if cookie_header then
      local updated
      cookie_header, updated = gsub(cookie_header, "sessionID=%x+", new_session_cookie)
      if updated==0 then
        cookie_header = cookie_header .. "; " .. new_session_cookie
      end
    else
      cookie_header = new_session_cookie
    end
    ngx.req.set_header("Cookie", cookie_header)
    local uri = ngx.req.get_uri_args()
    if uri["cmd"] then
      uri.auth = true
      local state, res = action(uri)
      if uri.cmd == "3" then
        if state and res and res.login_confirm
           and res.login_confirm.check_user == "1" and res.login_confirm.check_pwd == "1" then
          login(mgr, session, "user_default")
          session:store("persistent", untaint(uri.remember_me))
          session:store("loginflag", "1")
        end
        ngx.print(json.encode(res, {indent=true}))
      end
    else
      ngx.exit(ngx.HTTP_FORBIDDEN)
    end
  end
end

local function getSessionAddress()
  local ngx_var = ngx.var
  return {
    remote = untaint(ngx_var.remote_addr),
    server = untaint(ngx_var.server_addr),
  }
end

local function newSession(mgr, address)
  local session
  local sessionID
  if sessionLimitReached(mgr, address.remote) then
    -- the maximum number of sessions has been exceeded.
    return
  end
  -- Loop should only occur once and is here to avoid session ID clashes.
  while not sessionID or mgr.sessions[sessionID] do
    session = Session.new(address, mgr)
    sessionID = session.sessionid
  end
  addSession(mgr, session, sessionID)
  -- Set the cookie.
  setSessionCookie(mgr, sessionID)
  return session, sessionID
end

local function userActivityForSession(mgr, session)
  session.timestamp = clock_gettime(CLOCK_MONOTONIC)
  if mgr.assistant then
    mgr.assistant:activity()
  end
end

local function redirectIfServiceNotAvailable(session)
  if not session then
    ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
  end
end

local function getSessionForRequest(mgr, noActivityUpdate)
  local address = getSessionAddress()
  local session, sessionID = verifySession(mgr, address.remote)
  if not session then
    session, sessionID = newSession(mgr, address)
  elseif not noActivityUpdate then
    userActivityForSession(mgr, session)
  end
  return session, sessionID
end

-- store session object in nginx request context so
-- it can be accessed by content phase code (e.g. Lua Pages)
local function storeSessionInNginx(session)
  ngx.ctx.session = session.proxy
end

--- Check if the current request has a valid session and if it
-- is an authorized request.
-- @param noActivityUpdate (optional) if true, the user activity timer
--     for the session won't be updated.
function SessionMgr:checkrequest(noActivityUpdate)
  local session, sessionID = getSessionForRequest(self, noActivityUpdate)
  redirectIfServiceNotAvailable(session)
  redirectIfNotAuthorized(self, session, sessionID)
  storeSessionInNginx(session)
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

--- logout and remove all sessions unconditionally
function SessionMgr:invalidateSessions()
  for sid, session in pairs(self.sessions) do
    session:logout()
    removeSession(self, sid)
  end
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
    local index = dm.add(userspath)
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
  maxsessions = function(self, _, value)
    self.maxsessions = verify_sessionlimit_value(value, self.maxsessions)
  end,
  maxsessions_per_ip = function(self, _, value)
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

-- function to count all currently logged-in user sessions
-- @return userCount will return number of users
function SessionMgr:getUserCount()
  local userCount = 0
  for _,v in pairs(self.sessions) do
    if v:getusername() ~= "" and not v:isdefaultuser() then
      userCount = userCount + 1
    end
  end
  return userCount
end

local M = {}

function M.new(mgr_name, mgr_config, sessioncontrol)
  local new_mgr = setmetatable(
    {
      name = mgr_name,
      sessioncontrol = sessioncontrol,
      sessions = {},
      users = {},
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
  new_mgr._session_tracker = newSessionTracker()
  return new_mgr
end

return M
