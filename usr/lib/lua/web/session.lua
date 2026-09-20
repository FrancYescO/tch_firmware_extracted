local ngx = ngx
local setmetatable = setmetatable
local posix = require("tch.posix")
local clock_gettime = posix.clock_gettime
local CLOCK_MONOTONIC = posix.CLOCK_MONOTONIC

local Session = {}
Session.__index = Session

--- Return the username associated with the session.
-- @return #string The username associated with this session.
function Session:getusername()
  return (self.user and self.user.name) or ""
end

--- Returns whether the current user is the default user.
-- @return #boolean True if the current user is the default user; false otherwise.
function Session:isdefaultuser()
  local default_user = self.mgr.default_user
  if not default_user then
    return false
  end
  return (self.user == default_user)
end

function Session:toggleDefaultUser(value)
  if value then
    self.mgr:setDefaultUser(self.user)
  else
    self.mgr:setDefaultUser()
  end
end

--- Return the role associated with the session.
-- @return #string The role associated with this session.
function Session:getrole()
  return (self.user and self.user.role) or ""
end

--- Store a key-value pair in the session.
-- Anything stored this way will remain available during the
-- lifetime of the session (by using the retrieve method) and as
-- long as privileges are not dropped.
-- Once the session is over, everything in storage is discarded.
-- @param key   the key to use in storage
-- @param value the value to be stored
function Session:store(key, value)
  self.storage[key] = value
end

--- Retrieve a value previously stored in the session.
-- @param key   the key for which the value needs to be retrieved.
-- @return the value corresponding to the given key or nil if not found.
function Session:retrieve(key)
  return self.storage[key]
end

--- Perform a logout of the current user.
-- The current username and role are reverted to the default values
-- and everything in the storage cache is discarded.
function Session:logout()
  local mgr = self.mgr
  -- Invalidate storage
  self.storage = {}
  -- Revert user to default user
  self.user = mgr.default_user
  -- TODO: ideally we should also generate a new session ID and CSRF token
end

--- Verify if the given resource can be accessed with the current credentials.
-- @param resource   The resource which needs to be checked.
-- @return True if the given resource can be accessed by this session, false
--         otherwise.
function Session:hasAccess(resource)
  return (self.mgr:authorizeRequest(self, resource))
end

--- Retrieve the CSRF token associated with this session.
-- @return String with this session's CSRF token.
function Session:getCSRFtoken()
  return self.CSRFtoken
end

--- Validate the given token against the session's token.
-- If it doesn't match this function never returns; it ends
-- the request processing with a HTTP Forbidden status code.
-- @param token The token to check.
-- @return True if the token matches.
function Session:checkCSRFtoken(token)
  if token ~= self.CSRFtoken then
    ngx.log(ngx.ERR, "POST without CSRF token")
    ngx.exit(ngx.HTTP_FORBIDDEN)
  end
  return true
end

--- add the user whose instance name is provided to the list of allowed users for the session's manager
-- @param instancename
function Session:addUserToManager(instancename)
    return self.mgr:addUser(instancename)
end

--- remove the user whose instance name is provided from the list of allowed users to the session's manager
function Session:delUserFromManager(instancename)
    return self.mgr:delUser(instancename)
end

--- reload all users to update them if needed
function Session:reloadAllUsers()
  self.mgr.sessioncontrol.reloadUsers()
end

--- Change SRP parameters of the current user of this session.
function Session:changePassword(salt, verifier)
  return self.mgr.sessioncontrol.changePassword(self.user, salt, verifier)
end

--- Create a proxy for a session. This protects the session object
-- from tampering by code in the Lua pages.
-- @param session   The session for which we wish to create a proxy.
-- @return A read-only proxy object for the session with only the
--         desired API exposed. The real session object is hidden by the closure.
local function createProxy(session)
  -- TODO: more generic instead of wrapper function for each public function
  local getusername = function()
    return session:getusername()
  end
  local isdefaultuser = function()
    return session:isdefaultuser()
  end
  local toggleDefaultUser = function(_, value)
    return session:toggleDefaultUser(value)
  end
  local getrole = function()
    return session:getrole()
  end
  local store = function(_, key, value)
    session:store(key,value)
  end
  local retrieve = function(_, key)
    return session:retrieve(key)
  end
  local logout = function()
    session:logout()
  end
  local hasAccess = function(_, resource)
    return session:hasAccess(resource)
  end
  local getCSRFtoken = function()
    return session:getCSRFtoken()
  end
  local checkCSRFtoken = function(_, token)
    return session:checkCSRFtoken(token)
  end
  local addUserToManager = function(_, instancename)
    return session:addUserToManager(instancename)
  end
  local delUserFromManager = function(_, instancename)
    return session:delUserFromManager(instancename)
  end
  local reloadAllUsers = function()
      return session:reloadAllUsers()
  end
  local changePassword = function(_, salt, verifier)
    return session:changePassword(salt, verifier)
  end
  local proxy = {
    getusername = getusername,
    isdefaultuser = isdefaultuser,
    toggleDefaultUser = toggleDefaultUser,
    getrole = getrole,
    store = store,
    retrieve = retrieve,
    logout = logout,
    hasAccess = hasAccess,
    getCSRFtoken = getCSRFtoken,
    checkCSRFtoken = checkCSRFtoken,
    addUserToManager = addUserToManager,
    delUserFromManager = delUserFromManager,
    reloadAllUsers = reloadAllUsers,
    changePassword = changePassword
  }
  return setmetatable({}, {
    __index = proxy,
    __newindex = function()
      ngx.log(ngx.ERR, "Illegal attempt to modify session object")
    end,
    __metatable = "ah ah ah, you didn't say the magic word"
  });
end

local keylength = 32  -- in bytes
local key = ("%02x"):rep(keylength)
local fd = assert(io.open("/dev/urandom", "r"))

local function generateRandom()
  local bytes = fd:read(keylength)
  return key:format(bytes:byte(1, keylength))
end

local M = {}

--- Create a new session.
-- @param remoteIP   The remote IP linked to the new session. This should
--                   not change during a session.
-- @param mgr        The session manager that creates the new session.
-- @return A new session is returned that is initiated with the default
--         user and role.
function M.new(remoteIP, mgr)
  local session = {
    mgr = mgr,
    user = mgr.default_user,  -- note: default_user can be nil (meaning there is no default user)
    sessionid = generateRandom(),
    CSRFtoken = generateRandom(),
    remoteIP = remoteIP,
    timestamp = clock_gettime(CLOCK_MONOTONIC),
    storage = {},
  }
  setmetatable(session, Session)
  session.proxy = createProxy(session)
  return session
end

return M