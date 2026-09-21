
local pairs = pairs
local setmetatable = setmetatable

local WpsState = {}
WpsState.__index = WpsState

local function new_WpsState(ubus)
  return setmetatable({
    _ubus = ubus
  }, WpsState)
end

local function load_wpsstate(ubus)
  local state = {}
  local wps = ubus:call("wireless.accesspoint.wps", "get", {})
  for ap, wps_info in pairs(wps or {}) do
    if wps_info.oper_state == 1 then
      state[ap] = {
        enabled = wps_info.last_session_state == "inprogress",
      }
    end
  end
  return state
end

local function WpsState_currentState(wpsstate)
  local state = wpsstate._state
  if not state then
    state = load_wpsstate(wpsstate._ubus)
    wpsstate._state = state
  end
  return state
end

local function WpsState_forceReload(wpsstate)
  wpsstate._state = nil
end

function WpsState:enabled()
  local state = WpsState_currentState(self)
  for _, wps in pairs(state) do
    if not wps.enabled then
      return false
    end
  end
  return true
end

function WpsState:enable(enable)
  local ubus = self._ubus
  local state = WpsState_currentState(self)
  for ap in pairs(state) do
    ubus:call("wireless.accesspoint.wps", "enrollee_pbc", {name=ap, event=enable and "start" or "stop"})
  end
  WpsState_forceReload(self)
end

return {
  connect = function(ubus)
    return function()
      return new_WpsState(ubus)
    end
  end
}
