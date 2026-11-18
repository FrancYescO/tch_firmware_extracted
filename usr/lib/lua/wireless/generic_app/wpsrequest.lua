
local require = require
local setmetatable = setmetatable
local tonumber = tonumber

local uci = require('uci')

local UCI_CONFIG = "generic_app"
local UCI_SECTION = "wpsrequest"

local DEFAULT_UDP_PORT = 5555
local DEFAULT_INTERFACE = "lan"

local WpsRequest = {}
WpsRequest.__index = WpsRequest

local function WpsRequest_create()
  return setmetatable({}, WpsRequest)
end

local function WpsRequest_ucicursor(req)
  local cursor = req._cursor
  if not cursor then
    cursor = uci.cursor(nil, "/var/state")
    req._cursor = cursor
  end
  return cursor
end

function WpsRequest:close()
  local cursor = self._cursor
  if cursor then
    cursor:close()
    self._cursor = nil
  end
end

local function WpsRequest_setState(req, state)
  req._ucistate = { state }
  return state
end

local function WpsRequest_currentState(req)
  return req._ucistate and req._ucistate[1]
end

local function WpsRequest_ucistate(req)
  local state = req._ucistate
  if not state then
    local cursor = WpsRequest_ucicursor(req)
    WpsRequest_setState(req, cursor:get_all(UCI_CONFIG, UCI_SECTION))
  end
  return WpsRequest_currentState(req)
end

local function WpsRequest_ucistate_createIfNeeded(req)
  local state = WpsRequest_ucistate(req)
  if not state then
    local cursor = WpsRequest_ucicursor(req)
    cursor:set(UCI_CONFIG, UCI_SECTION, UCI_SECTION)
    state = WpsRequest_setState(req, {})
  end
  return state
end

function WpsRequest:requested()
  if self._requested then
    return self._requested
  end
  local state = WpsRequest_ucistate(self)
  if state then
    return state.requested or ""
  end
end

function WpsRequest:request(newRequest)
  local oldRequest = self:requested()
  local changed = oldRequest~=newRequest
  if changed then
    self._requested = newRequest
  end
  return changed
end

function WpsRequest:udpPort()
  local port
  local state = WpsRequest_ucistate(self)
  if state then
    port = tonumber(state.udpport)
  end
  return port or DEFAULT_UDP_PORT
end

function WpsRequest:interface()
  local intf
  local state = WpsRequest_ucistate(self)
  if state then
    intf = state.interface
  end
  return intf or DEFAULT_INTERFACE
end

local function WpsRequest_saveRequestedValue(req, state)
  local cursor = WpsRequest_ucicursor(req)
  cursor:set(UCI_CONFIG, UCI_SECTION, "requested", req._requested)
  state.requested = req._requested
  cursor:save(UCI_CONFIG)
end

function WpsRequest:save()
  if self._requested then
    local state = WpsRequest_ucistate_createIfNeeded(self)
    WpsRequest_saveRequestedValue(self, state)
    self._requested = nil
  end
end

function WpsRequest:revert()
  self._requested = nil
end

return {
  WpsRequest = WpsRequest_create,
}
