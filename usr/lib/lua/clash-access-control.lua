local uci = require("uci")
local posix = require("tch.posix")
local iim = require("ip-intf-match")

local logger = require("transformer.logger")
local log = logger.new("clash-access-control", 4) --notice

local getenv = os.getenv
local format = string.format

--- get clash config for current user
-- @return table table respresenting the current user's clash config,
--   or empty table if not config found
local function config()
  local cfg
  local username = posix.getusername()
  if username then
    local cursor = uci.cursor()
    cfg = cursor:get_all("clash", username)
  end
  return cfg or {}
end

--- test if a UCI option is set to `1`
-- @tparam string conntype the connection type to test.
--   Should be `ssh`, `serial` or `telnet`, but the function accepts any string.
-- @return boolean true if UCI option `conntype` is set to 1,
--   false otherwise
local function uci_flag(conntype)
  local cfg = config()
  local result = (cfg[conntype] == "1")
  log:notice(format("User %s has %s%s access", cfg['.name'] or "(unknown)", (result and "" or "no "), conntype or ""))
  return result
end

--- get this side's IP address for a SSH session
-- @return string ip this side's IP address of a SSH connection with a peer,
--   nil if no address found
local function getip()
  local ipenv = getenv("SSH_CONNECTION")
  if ipenv then
    -- space-separated; third part is our IP address
    local _, _, ip = ipenv:match("^(.-) (.-) ([%w%.%:]*)")
    return ip
  end
end

--- test if the current user's SSH session comes in over one of their
--   allowed interfaces.
-- @return string the network interface in the user's list of allowed interfaces that
--   that matches this session's network interface, or nil if no match is found
local function ssh_intf()
  local cfg = config()
  local user = cfg['.name'] or "(unknown)"
  -- by specification, if simple ssh access is enabled, disregard list option ssh_interface
  if cfg.ssh then
    local access = (cfg.ssh == "1")
    log:notice(format("User %s has %s ssh access", user, (access and "" or "no")))
    return access
  elseif cfg.ssh_interface then
    -- if ssh_interface list option provided, then go ahead and check if one
    -- of the user's interfaces matches our IP address
    local intf = iim.match(getip(), cfg.ssh_interface)
    if intf then
      log:notice(format("User %s has ssh access over %s", user, intf))
    else
      log:notice(format("User %s is logging in over none of their allowed interfaces", user))
    end
    return intf
  end
  log:notice(format("User %s has no ssh access", user))
end

-- simple table with validator functions for each connection type
local validators = {
  serial = uci_flag,
  telnet = uci_flag,
  ssh = ssh_intf,
}

--- the entrypoint of the module
-- @tparam string conntype is the connection type to test,
--   should be `ssh`, `serial` or `telnet`, but the function accepts any string
-- @return true if the user is granted access according to their configuration,
--   nil plus error message otherwise
local function main(conntype)
  local v = validators[conntype]
  if v and v(conntype) then
    return true
  end
  return nil, "No access for current user"
end

return { check = main }
