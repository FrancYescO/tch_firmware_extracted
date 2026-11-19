-- Copyright (c) 2019 Technicolor
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

--- Gateway will receive an authentication message(contains a salt value) from the backend to be able to authenticate the end user.
-- On receiving this message, Gateway replies with a response message containing "salt;hashoversaltedpassword" and a status code of 200
-- Backend takes care of validation/authentication of the salt hashed over password
--
-- @module authentication_handler
--

local proxy = require("datamodel")
local M = {}
local mqtt_lookup = {}
local log
local process = require("tch.process")
local popen = process.popen
local crypto = require("tch.crypto")
local authData = {}
local mqttHandler

--- Hashed key generation(using get_access_key and salt obatined from input) for authentication messages
-- @function getHashedKey
-- @param salt Random data used to hash the password
-- @return hashed key
local function getHashedKey(salt)
  local data = process.popen("get_access_key", {"1"})
  if data and salt then
    local password = data:read()
    data:close()
    if password and #password > 0 then
      local hashedKey = crypto.sha256(salt .. password)
      return hashedKey and salt .. ";" .. hashedKey
    end
  end
end

local sendAuthResponse

--- Handles the received wps button event. If, the "wps button press" event received, authentication response will be sent.
-- @function wpsPressEventHandler
-- @param data wps button ubus event data
local function wpsPressEventHandler(data)
  if data.wps == "pressed" and sendAuthResponse then
    mqtt_lookup.ubusConn:call("wireless.accesspoint.wps", "enrollee_pbc", { event = "stop" })
    mqttHandler.authResponse(mqttHandler.notifyConnections, authData)
    sendAuthResponse = false
  end
end

--- Triggers authentication message with a hashed key for verification to the Cloud.
-- @function triggeerAuthMessage
-- @param payload Request message from cloud.
-- @return table
-- @error For physical authentication, type should be wps and timeout has to be mentioned.
local function triggerAuthMessage(payload)
  local saltValue = getHashedKey(payload.salt)
  authData = {
    requestId = payload.requestId,
    key = saltValue,
    status = saltValue and mqtt_lookup.mqtt_constants.authSuccess or mqtt_lookup.mqtt_constants.authError
  }
  -- Physical authentication in auth request is ignored when configurable parameter 'ignore_physical_auth' is set to 1.
  if not payload.physicalAuthentication or mqtt_lookup.config.ignorePhysicalAuth == 1 then
    return authData or {}
  elseif payload.physicalAuthentication.type == "wps" and payload.physicalAuthentication.timeout then
    sendAuthResponse = true
    log:info("Listening wps button event for physical auth response")
    mqtt_lookup.ubusConn:listen{
      ["button"] = wpsPressEventHandler,
    }
    mqtt_lookup.uloop.timer(function()
      sendAuthResponse = false
      log:info("Physical authentication timed out")
    end, payload.physicalAuthentication.timeout * 1000)
  else
    log:error("For physical authentication, type should be wps and timeout has to be mentioned.")
  end
end

--- Handles the Authentication requests, and sends authentication response message to the back-end for verification.
-- @function auth
-- @param payload authentication request message from Mobile App
-- @param lookup table containing the config data for the module parameter
-- @param handler
-- @return table response from the authentication handler
-- @error Authentication Request without a salt value
-- @error Authentication Request without a requestId value
-- @error Device not registered! Retry authentication after successful registration
function M.auth(lookup, payload, handler)
  mqtt_lookup = lookup
  local logInfo = "mqttpayloadhandler ReqId: " .. (payload.requestId or "")
  log = mqtt_lookup.logger.new(logInfo, mqtt_lookup.config.logLevel)
  local registerStatus = mqtt_lookup.config.register
  mqttHandler = handler
  if payload and registerStatus == 1 then
    if payload.salt and payload.requestId then
      return triggerAuthMessage(payload)
    elseif not payload.salt then
      log:error("Authentication Request without a 'salt' value")
    end
  else
    log:error("Device not registered! Retry authentication after successful registration")
  end
end

return M
