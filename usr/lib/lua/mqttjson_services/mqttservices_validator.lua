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

--- Values given in mqtt request are validated.
-- Validators for mqtt parameter values are handled here.
--
-- @module mqttservices_validator
--

local M = {}
M.mqtt_lookup = {}
local nwCommon = require("transformer.mapper.nwcommon")
local posix = require("tch.posix")
local AF_INET = posix.AF_INET
local find, match, sub, gmatch = string.find, string.match, string.sub, string.gmatch

local supportedFirewallModes = {
  lax = true,
  normal = true,
  high = true,
  user = true
}

local weekdays = {
  Mon = true,
  Tue = true,
  Wed = true,
  Thu = true,
  Fri = true,
  Sat = true,
  Sun = true
}

local supportedProtocol = {
  tcp = true,
  udp = true,
  tcpudp = true
}

--- Retrieves the valid channels for given wireless radio.
-- @function getValidChannels
-- @param radio wireless radio - radio2G/ radio5G.
-- @return list of valid channels.
local function getValidChannels(radio)
  local validRadioChannels = { "auto" }
  local radioData = M.mqtt_lookup.ubusConn:call("wireless.radio", "get", { name = radio }) or {}
  local allowedChannels = radioData[radio] and radioData[radio]["allowed_channels"] and tostring(radioData[radio]["allowed_channels"]) or ""
  for channel in gmatch(allowedChannels, "%S+") do
    validRadioChannels[#validRadioChannels + 1] = tostring(channel)
  end
  return validRadioChannels
end

--- Retrieves the supported modes of given wireless AP.
-- @function getSupportedModes
-- @param ap wireless AP
-- @return list of supported modes
local function getSupportedModes(ap)
  local validSecurityModes = {}
  local apData = M.mqtt_lookup.ubusConn:call("wireless.accesspoint.security", "get", { name = ap }) or {}
  local supportedModes = apData[ap] and apData[ap]["supported_modes"] or ""
  for mode in gmatch(supportedModes, "%S+") do
    validSecurityModes[#validSecurityModes + 1] = mode
  end
  return validSecurityModes
end

local validRadioChannelWidth = {
  radio_2G = {
    ["auto"] = true,
    ["20MHz"] = true,
    ["20/40MHz"] = true
  },
  radio_5G = {
    ["auto"] = true,
    ["20MHz"] = true,
    ["20/40MHz"] = true,
    ["20/40/80MHz"] = true
  }
}

--- Validates the given value is string or not.
-- @function isString
-- @param value value to be validated.
-- @return true / false
function M.isString(value)
  return type(value) == 'string' and #value > 0 and true or false
end

--- Validates the given value is boolean or not.
-- @function isBoolean
-- @param value value to be validated
-- @return true / false
function M.isBoolean(value)
  if value == 'true' or value == 'false' or tonumber(value) == 1 or tonumber(value) == 0 then
    return true
  end
  return false
end

--- Validates the given value is threshold or not.
-- @function validateRssiThreshold
-- @param value value to be validated
-- @return true / false
function M.validateRssiThreshold(value)
  return tonumber(value) and tonumber(value) <= 0 and true or false
end

--- Validates the given firewall mode.
-- @function validateFirewallMode
-- @param mode value to be validated
-- @return true / false
function M.validateFirewallMode(mode)
  return supportedFirewallModes[mode] and true or false
end

--- Validates the given value is valid mac address.
-- @function isValidMac
-- @param value mac address to be validated
-- @return true / false
function M.isValidMac(value)
  return nwCommon.isMAC(value)
end

--- Validates the given TOD mode.
-- @function validateTodMode
-- @param value value to be validated
-- @return true / false
function M.validateTodMode(value)
  if value == "block" or value == "allow" then
    return true
  end
  return false
end

--- Validates the given value is in Time format.
-- @function validateTime
-- @param value value to be validated
-- @return true / false
function M.validateTime(value)
  local hours, mins = value:match("^(%d+):(%d+)$")
  hours, mins = tonumber(hours), tonumber(mins)
  if hours and mins and hours >= 0 and hours < 24 and mins >=0 and mins < 60 then
    return true
  end
  return false
end

--- Validates the given TOD Type.
-- @function validateTodType
-- @param value value to be validated
-- @return true / false
function M.validateTodType(value)
  return value == 'mac' and true or false
end

--- Validates the given weekdays
-- @function validateWeekday
-- @param value value to be validated
-- @return true / false
function M.validateWeekday(value)
  return weekdays[value] or false
end

--- Validates the given value is valid url
-- @function isValidURL
-- @param site url to be validated
-- @return true / false
function M.isValidURL(site)
  if type(site) == 'string' then
    --extract only domain part in URL
    site = site:match("[%w]+://([^/ ]*)") or site:match("([^/ ]*)") or site
    -- check if the site starts with www then remove it from URL.
    local domain = site:match("^www%.(%S+)") or site
    -- Domain name cannot be empty or too long
    if not domain or #domain == 0 or #domain > 255 then
      return false
    end

    local i, index = 0, 0
    repeat
      i = i+1
      index = find(domain, ".", i, true)
      local label = sub(domain, i, index)
      local strippedLabel = match(label, "[^%.]*")
      -- Domain name segments is not separated by dots
      if i == 1 and index == nil then
        return false
      end
      if strippedLabel ~= nil then
        -- Dot at start or end of domain name is not allowed. Successive dots are not allowed in domain name.
        if #strippedLabel == 0 then
          return false
        end
        -- Domain name segments (seperated by dots) cannot be longer than 63 characters.
        if #strippedLabel > 63 then
          return false
        end
        local correctLabel = match(strippedLabel, "^[%w][%w%-]*[%w]")
        if #strippedLabel == 1 then
          -- Domain name segments (seperated by dots) of single character length cannot be a special character.
          if not match(strippedLabel, "[a-zA-Z0-9]") then
            return false
          end
         -- Domain name should start and end only with alphanumeric characters.
         -- Domain name cannot contain white space or special characters other than hyphen or dot.
        elseif strippedLabel ~= correctLabel then
          return false
        end
      end
      i = index
    until not index
    return true
  end
  return false
end

--- Validates the given device type for URL Filtering
-- @function validateURLfilterDevice
-- @param value device type to be validated
-- @return true / false
function M.validateURLfilterDevice(value)
  local validDeviceValue = {
    all = true,
    single = true
  }
  return validDeviceValue[value] or false
end

--- Validates the given action for the URL Filtering.
-- @function validateURLfilterAction
-- @param value action
-- @return true / false
function M.validateURLfilterAction(value)
  local validActions = {
    DROP = true,
    drop = true,
    ACCEPT = true,
    accept = true
  }
  return validActions[value] or false
end

--- Validates wireless SSID.
-- @function validateSSID
-- @param value wireless SSID
-- @return true / false
function M.validateSSID(value)
  if type(value) == "string" and #value > 0 and #value <= 32 then
    local validSSID = "^[^?\"$%[%]+\\\t]*$"
    local validStart = "^[^%s#!;]"
    -- SSID should not start with ; # ! and space
    if not value:match(validStart) then
      return false
    -- SSID should not contain ?, ", $, [, \, ], tab and + special characters
    elseif not value:match(validSSID) then
      return false
    end
    return true
  end
  return false
end

--- Validates wireless AP pin. Value should be 8 digit pin.
-- @function validatApPin
-- @param value wireless AP pin
-- @return true / false
function M.validateApPin(value)
  value = tonumber(value)
  return value and match(value, "^%d%d%d%d%d%d%d%d$") and true or false
end

--- Validates the WPA PSK passphrase.
-- @function validateWpaPassphrase
-- @param value WPA PSK passphrase
-- @return true / false
function M.validateWpaPassphrase(value)
  if type(value) == "string" and #value >= 8 and #value <= 64 then
    -- For a length of 64 characters, only numbers and letters from A to F are accepted
    if #value == 64 and not value:match("^[a-fA-F0-9]+$") then
      return false
    end
    return true
  end
  return false
end

--- Validates the requested channel for wireless radio.
-- @function validateReqChannel
-- @param value wireless radio requested channel
-- @param radio wireless radio
-- @return true / false
function M.validateReqChannel(value, radio)
  local validRadioChannels = getValidChannels(radio)
  for _, channel in ipairs(validRadioChannels) do
    if value == channel then
      return true
    end
  end
  return false
end

--- Validates the requested channel width for wireless radio.
-- @function validateReqChannelWidth
-- @param value wireless radio requested channel width
-- @param radio wireless radio
-- @return true / false
function M.validateReqChannelWidth(value, radio)
  return validRadioChannelWidth[radio] and validRadioChannelWidth[radio][value] and true or false
end

--- Validates the wireless AP security mode.
-- @function validateSecurityMode
-- @param value security mode of wireless ap.
-- @param ap wireless ap
-- @return true/ false
function M.validateSecurityMode(value, ap)
  local supportedModes = getSupportedModes(ap)
  for _, mode in ipairs(supportedModes) do
    if value == mode then
      return true
    end
  end
  return false
end

--- Validates the given value is valid IP address.
-- @function isValidIP
-- @param value IP address to be validated
-- @return true / false
function M.isValidIP(value)
  local rc = posix.inet_pton(AF_INET, value)
  if rc then
    local b1, b2, b3, b4 = rc:byte(1, 4)
    local ipNum = (b1 * (256^3)) + (b2 * (256^2)) + (b3 * 256) + b4
    return ipNum and true or false
  end
  return false
end

--- Validates the user password.
-- @function validatePassword
-- @param value password
-- @return true / false
function M.validatePassword(value)
  if type(value) == "string" and #value >= 12 and match(value, "%l") and match(value, "%u") and match(value, "%p") and match(value,"%d") then
    return true
  end
  return false
end

--- Validates the port value
-- @function validatePort
-- @param value port
-- @return true / false
function M.validatePort(value)
  value = tonumber(value)
  return value and (math.floor(value) == value) and value >= 1 and value < 65536 and true or false
end

--- Validates the given protocol
-- @function validateProtocol
-- @param value protocol to be validated
-- @return true / false
function M.validateProtocol(value)
  return supportedProtocol[value] or false
end

--- Validates the portforwarding rule family.
-- @function validatePfwFamily
-- @param value portwarding rule family
-- @return true / false
function M.validatePfwFamily(value)
  return value == 'ipv4' and true or false
end

--- Validates the given value is valid subnet mask.
-- @function isValidSubnetMask
-- @param value subnet mask to be validated
-- @return true / false
function M.isValidSubnetMask(value)
  return nwCommon.isValidIPv4SubnetMask(value)
end

return  M
