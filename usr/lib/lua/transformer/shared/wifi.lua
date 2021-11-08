local M = {}
local gmatch, ipairs, concat = string.gmatch, ipairs, table.concat
local uciHelper = require("transformer.mapper.ucihelper")
local getFromUci = uciHelper.get_from_uci
local setOnUci = uciHelper.set_on_uci
local forEachOnUci = uciHelper.foreach_on_uci
local addOnUci = uciHelper.add_on_uci
local ubus = require("ubus")
local conn = ubus.connect()
local wirelessBinding = { config = "wireless", sectiontype = "wifi-ap" }
local multiapBinding = { config = "multiap", option = "enabled" }
local userFriendlyNameBinding = { config = "user_friendly_name" }

local apSupportedModes = {}
uciHelper.foreach_on_uci(wirelessBinding, function(s)
   if s.supported_security_modes then
     apSupportedModes[s[".name"]] = s.supported_security_modes
   else
     local data = conn:call("wireless.accesspoint.security", "get", { name = s[".name"] }) or {}
     apSupportedModes[s[".name"]] = data[s[".name"]] and data[s[".name"]].supported_modes or ""
   end
end)

--- function to convert a string into a map based on the match pattern
-- @param #string str the input string that needs to be converted into a map
-- @param #string matchPattern value containing the pattern to be applied for generating table keys
-- @param #string validateInputPattern optional If present, then the matched string is validated with the pattern provided.
-- @return #table tbl containing the map of elements that were converted from the input string
-- @return #nil if parameter validateInput is true and the input does not match validateInputPattern
--   the function returns nil, along with an error message "Invalid Value"
local function toMap(str, matchPattern, validateInputPattern)
  local tbl={}
  for item in gmatch(str , matchPattern) do
    if validateInputPattern and not item:match(validateInputPattern) then
      return nil, "Invalid Value"
    end
    tbl[item] = true
  end
  return tbl
end

--- function to convert a string into a list based on the match pattern
-- @param #string str the input string that needs to be converted into a list
-- @param #string matchPattern value containing the pattern to be applied for generating list elements
-- @param #string validateInputPattern optional If present, then the matched string is validated with the pattern provided.
-- @return #table tbl containing the list of elements that were converted from the input string
-- @return #nil if parameter validateInput is true and the input does not match validateInputPattern
--   the function returns nil, along with an error message "Invalid Value"
local function toList(str, matchPattern, validateInputPattern)
  local tbl = {}
  for item in gmatch(str, matchPattern) do
    if validateInputPattern and not item:match(validateInputPattern) then
      return nil, "Invalid Value"
    end
    tbl[#tbl+1] = item
  end
  return tbl
end

--- function to manipulate basic values in rateset option
--  the existing non-basic values are preserved and the existing basic values are over-written
--  In case the input contains a value which is already an existing non-basic value, then it is converted into a basic value.
-- @param #string value The value that needs to be set
-- @param #string rateset The rateset fetched from uci
-- @return #string containing the Basic Rateset list.
-- @return #nil when the input string is not a properly formatted string of (comma or space separated) integer or float values,
--   the function returns nil, along with an error message "Invalid Value"
function M.setBasicRateset(value,rateset)
  local ratesetTable = string.gsub(rateset, "%d*%.*%d*%(b%)[,%s]?", "") -- removes all the values containing (b)
  ratesetTable = toList(ratesetTable, "([^,%s]+)")
  local basicRatesetMap, errMsg = toMap(value, "([^,%s]+)", "^%d+%.?%d*$") -- match all comma or space separated values, validate if match contains numbers
  if not basicRatesetMap then
    return nil, errMsg
  end
  for index, rate in ipairs(ratesetTable) do
    if basicRatesetMap[rate] then -- If the rate is in the basic rates map append "(b)" and add to result list
      ratesetTable[index] = rate .. "(b)"
      basicRatesetMap[rate] = nil
    end
  end
  for rate in pairs(basicRatesetMap) do
    ratesetTable[#ratesetTable+1] = rate .. "(b)" -- Add the new basic rate values to the result list
  end
  return concat(ratesetTable," ")
end

--- function to manipulate operational values in rateset option
--   operational will have basic and other values
--   if value given is already present as basic then it should be retained as such
-- @param #string value The value that needs to be set
-- @param #string rateset The rateset fetched from uci
-- @return #string containing the Operational Rateset list.
-- @return #nil when the input string is not a properly formatted string of (comma or space separated) integer or float values,
--   the function returns nil, along with an error message "Invalid Value"
function M.setOperationalRateset(value,rateset)
  local errMsg
  local basicRatesetMap = toMap(rateset, "([^,%s]+)%(b%),?") -- match only values containing '(b)'
  value, errMsg = toList(value, "([^,%s]+)", "^%d+%.?%d*$") -- match all comma or space separated values, validate if match contains numbers
  if not value then
    return nil, errMsg
  end
  for index, rate in ipairs(value) do
    if basicRatesetMap[rate] then -- If the rate is in the basic rates map append "(b)" and add to result list
      value[index] = rate .. "(b)"
      basicRatesetMap[rate] = nil
    end
  end
  for rate in pairs(basicRatesetMap) do
    value[#value+1] = rate .. "(b)"
  end
  return concat(value," ")
end

--- Checks if the given security mode is supported or not
-- @function isSupportedMode
-- @param ap the accesspoint name
-- @param mode given mode to check whether it is in supported security modes
function M.isSupportedMode(ap, mode)
  local modeList = apSupportedModes[ap]
  for imode in modeList:gmatch('([^%s]+)') do
    if imode == mode then
      return true
    end
  end
  return false
end

-- function to calculate the signal strength of wireless device
function M.getSignalStrength(rssi)
  local strength = 1
  if rssi then
    if rssi  <= -85 then
      strength = "1"
    elseif rssi <= -75 and rssi > -85 then
      strength = "2"
    elseif rssi <= -65 and rssi  > -75 then
      strength = "3"
    elseif rssi  > -65 then
      strength = "4"
    end
  end
  return tostring(strength)
end

-- function to set the transmit power of wireless device
function M.setTxPower(maxPower, value)
  local tmp_power = ((value -100) * maxPower) / 100
  return math.ceil(tmp_power)
end

-- function to get the transmit power of wireless device
function M.getTxPower(max_target_power, max_target_power_adjusted)
  local tx_power = ""
  local tmp_power = 0
  if max_target_power and max_target_power_adjusted then
    if max_target_power ~= "0.0" then
      tmp_power = (max_target_power_adjusted/max_target_power) * 100
    end
    local power = tmp_power and math.ceil(tmp_power) or 0
    local roundOff = tmp_power and math.floor(tmp_power / 10) or 0
    tx_power = power and power % 10 or 0
    if tx_power > 5 then
      tx_power = (roundOff + 1) * 10
    else
      tx_power =  roundOff * 10
    end
  end
  return tx_power
end

function M.isControllerEnabled()
  multiapBinding.sectionname = "controller"
  return getFromUci(multiapBinding) == "1" and true or false
end

function M.isAgentEnabled()
  multiapBinding.sectionname = "agent"
  return getFromUci(multiapBinding) == "1" and true or false
end

function M.getUserFriendlyName(key)
  local friendlyName
  userFriendlyNameBinding.sectionname = nil
  forEachOnUci(userFriendlyNameBinding, function(s)
    if(s['mac'] == key) then
      friendlyName = s.name
      return false
    end
  end)
  return friendlyName or  ""
end

local function setUciValue(sectionname, option, value)
  userFriendlyNameBinding.sectionname = sectionname
  userFriendlyNameBinding.option = option
  setOnUci(userFriendlyNameBinding, value, commitapply)
end

function M.setUserFriendlyName(key, value, commitapply)
  local macPresent = false
  userFriendlyNameBinding.sectionname = nil
  forEachOnUci(userFriendlyNameBinding, function(s)
    if(s['mac'] == key) then
      setUciValue(s['.name'], "name", value)
      macPresent = true
      return false
    end
  end)
  if not macPresent then
    userFriendlyNameBinding.sectionname = 'name'
    userFriendlyNameBinding.option = nil
    local newSectionName = uciHelper.add_on_uci(userFriendlyNameBinding)
    if newSectionName then
      setUciValue(newSectionName, "mac", key)
      setUciValue(newSectionName, "name", value)
    end
  end
end

return M
