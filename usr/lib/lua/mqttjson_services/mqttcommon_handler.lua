-- Copyright (c) 2020 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.

-- Script connects to specified IOT Thing
-- Receives an MQTT Messages which contains the TR069 datamodel parameter
-- Sends an MQTT Message response of the specified TR069 datamodel parameter
-- The TR069 datamodel parameter can be IGD or Device2 datamodel.
-- The script is derived from the existing orchestra agent.

--- Contains the list of common functions used for the MQTT API's request/response interaction.
--
-- @module mqttcommon_handler
--

-- This table contains the list of common functions used for the MQTT API's request/response interaction.
local M = {}
local mqtt_lookup = {}
local log
local match, find, gsub, format = string.match, string.find, string.gsub, string.format

--- Generates a 16 digit random key
-- @function getRandomkey
-- @return 16 digit random key.
function M.getRandomKey()
  local bytes
  local key = ("%02X"):rep(8)
  local fd = io.open("/dev/urandom", "r")
  if fd then
    bytes = fd:read(8)
    fd:close()
  end
  return key:format(bytes:byte(1, 8)) or ""
end

--- Checks the given values are equal or matched
-- @function isEqual
-- @param val1 first value
-- @param val2 second value
-- @return true
function M.isEqual(val1, val2)
  if val1 and val2 then
    if (val1 == val2) or match(val1, val2) then
      return true
    elseif val2 and find(val2, "%-") then
      val2 = gsub(val2, "-", "%%-")
      if val1 and match(val1, val2) then
        return true
      end
    end
  end
end

--- Checks the requested parameter is white-listed or not.
-- @function isWhiteListed
-- @param reqParam Requested parameter
-- @param whiteListParams List of whiteList params
-- @return successcode, nil, dmPath
-- @error Given Parameter or input format is Incorrect
function M.isWhiteListed(reqParam, whiteListParams)
  if reqParam then
    for _, dmPath in pairs(whiteListParams or {}) do
      if M.isEqual(reqParam, dmPath) then
        return mqtt_lookup.mqtt_constants.successCode, nil, dmPath
      end
    end
  end
  log:warning(reqParam .. " is a non-whitelisted parameter")
  return mqtt_lookup.mqtt_constants.generalError, "Given parameter or input format is Incorrect"
end

--- Validates the value and returns success / error code based on defined validations for the parameters.
-- @function validateValue
-- @param req Request parameter
-- @param dmPath data modal path
-- @return sucess/ error code.
function M.validateValue(req, dmPath)
  local validator = mqtt_lookup.validator_mapper[dmPath]
  if type(validator) == 'table' then
    local param = match(req.parameter, "%S*%.(%S*)$")
    validator = validator[param]
  end
  local isValid
  local key = match(req.parameter, "%.@(%S+)%.%S+$")
  key = key and match(key, "(%S+)%.%S+$") or key
  if validator then
    isValid = type(validator) == 'boolean' and validator or mqtt_lookup.mqtt_validators[validator](req.value, key)
  end
  -- When no validator included for the requested param, a log msg will be displayed and success code will be returned.
  if not validator then
    log:info(req.parameter .." value is not validated")
  -- For invalid value, error code will be returned.
  elseif not isValid then
    return mqtt_lookup.mqtt_constants.generalError, "Invalid value for " ..req.parameter
  end
  return mqtt_lookup.mqtt_constants.successCode
end

-- Requiring special behaviour files from the path specified.
local lfs = require 'lfs'

--- Checks mode of a file
-- @function fileType
-- @param fileName file name
-- @return file mode
local function fileType(fileName)
  return lfs.attributes(fileName, "mode")
end

--- Checks the given file is hidden or not.
-- @function hiddenFile
-- @param fileName file name
-- @return file name
local function hiddenFile(fileName)
  return fileName:match("^%.")
end

--- lists all the available files present in the given path.
-- @function dirWalk
-- @param path path to the files
-- @return table
function M.dirWalk(path)
  local featuresTable = {}
  if path then
    for fileName in lfs.dir(path) do
      if fileName and fileType(path .. fileName) == "file" and not hiddenFile(fileName) then
        featuresTable[#featuresTable + 1] = match(fileName, "^(%S*)(.lua)$")
      end
    end
  end
  return featuresTable
end

--- loads the config data to module parameters.
-- @function init
-- @param lookup table containing config data for the module parameter
function M.init(lookup)
  mqtt_lookup = lookup
  log = mqtt_lookup.logger.new("mqttcommonhandler", mqtt_lookup.config.logLevel)
end

return M
