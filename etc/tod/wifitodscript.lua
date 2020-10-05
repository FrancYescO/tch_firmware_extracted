local M = {}

-- Set wireless interface state to enable/disable
-- @function setStates
-- @param #table runtime Lua table containing contexts: {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- @param #string state enable/disable WiFi 2G,5G interface
local function setStates(cursor, state)
  cursor:set("wireless", "radio_2G", "state", state)
  cursor:set("wireless", "radio_5G", "state", state)
  cursor:commit("wireless")
end

-- Reloads hostapd to physically update radio/ssid
-- @function refreshHostapd
local function refreshHostapd()
  os.execute("/etc/init.d/hostapd reload; sleep 3")
end

-- Routine invoked when "start_time" has been reached in scheduler
-- @param #table runtime Lua table containing contexts: {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- @param #string actionname UCI tod "action" section name to operate on
-- @param #string object UCI "object" option pointing to tod "wifitod" information (e.g. "wifitod1" can contain specific set of APs)
-- @return #boolean true to continue with state machine, false if error encountered (causes this script to exit)
function M.start(runtime, actionname, object)
  local cursor = runtime.uci.cursor()
  if not cursor then
    return false
  end
  setStates(cursor, "0")
  refreshHostapd()
  return true
end

-- Routine invoked when "stop_time" has been reached in scheduler
-- @param #table runtime Lua table containing contexts: {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- @param #string actionname UCI tod "action" section name to operate on
-- @param #string object UCI "object" option pointing to tod "wifitod" information (e.g. "wifitod1" can contain specific set of APs)
-- @return #boolean true to continue with state machine, false if error encountered (causes this script to exit)
function M.stop(runtime, actionname, object)
  local cursor = runtime.uci.cursor()
  if not cursor then
    return false
  end
  local wifitod_dis = cursor:get("tod", actionname, "enabled")
  if wifitod_dis == "1" then
    setStates(cursor, "1")
    refreshHostapd()
  end
  local periodic = cursor:get("tod", "wifidisable_timer", "periodic")
  if periodic == "0" then
    cursor:set("tod", actionname, "enabled", "0")
    cursor:commit("tod")
  end
  return true
end

return M
