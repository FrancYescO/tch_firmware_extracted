-- Copyright (c) 2018 Technicolor Delivery Technologies, SAS

---------------------------------
-- Config module to retreive information from uci.
---------------------------------

local runtime = {}
local M = {}
local uciConfig = {}
local multiapConfig = "multiap"
local uci
local cursor

--- Loads configuration from uci
-- @treturn #table The entire controller config section
function M.loadConfig()
  uci = runtime.uci
  cursor = uci.cursor()
  local config = cursor:get_all(multiapConfig, "controller")
  return config
end

--- Retrieves multiap controller status
-- @treturn #boolean status of the controller
function M.getControllerStatus()
  return uciConfig.enabled or 0
end

--- Retrieves trace level
-- @treturn #integer traceLevel
function M.getTraceLevel()
  local traceLevel = cursor:get("vendorextensions", "multiap_vendorextensions", "trace_level")
  return traceLevel and tonumber(traceLevel) or 3
end

--- Retrieves value from given uci path
-- @tparam #string config config file from which value is to be retrieved
-- @tparam #string sectionname sectionname from which value is to be retrieved
-- @tparam #string option option from which value is to be retrieved
-- @treturn #string value at given uci path
function M.getUciValue(config, sectionname, option)
  if not config or not sectionname or not option then
    runtime.log:error("Invalid uci config or sectionname or option")
    return
  end
  local value = cursor:get(config, sectionname, option)
  if not value then
    runtime.log:error("Given config or sectionname or option is not present in uci")
  end
  return value or ""
end

--- Retrieves multiap controller power on time
-- @treturn #string Power on time of the controller
function M.getControllerPowerOnTime()
  local state_cursor = uci.cursor(nil, "/var/state")
  local value = state_cursor:get("multiap", "controller", "poweron_time")
  return value or ""
end

--- Retrieves multiap controller reset time
-- @treturn #string Power on time of the controller
function M.getFactoryResetTime()
  local state_cursor = uci.cursor(nil, "/var/state")
  local value = state_cursor:get("multiap", "controller", "factoryreset_time")
  return value or ""
end

--- Retrieves Multiap agent alias name
-- @tparam #string mac address of multiap agent
-- @treturn #string Alias name of multiap agent
function M.getAgentAliasName(mac)
  cursor = uci.cursor()
  local sectionName = string.gsub(mac, "%:", "") .."_alias"
  return cursor:get("vendorextensions", sectionName, "Alias") or ""
end

function M.init(rt)
  runtime = rt
  uciConfig = M.loadConfig()
end

return M
