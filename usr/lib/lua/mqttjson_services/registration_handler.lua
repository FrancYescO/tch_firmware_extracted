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

--- After establishing a secured connection with the Cloud, gateway send a registration request message to the Cloud.
-- This registration request contains gateway information such as serial number, protocol version, agent version, datamodel, device-model, sw-version.
-- Upon receiving the request, cloud sends back a registration response code with a status code in it.
-- Registration becomes successful, if the request_id matches and the status code equals to 200.
-- After successful registration, other API operations can be performed.
--
-- @module registration_handler
--

local proxy = require("datamodel")
local M = {}
local mqtt_lookup = {}
local log

--- Function to check whether registration is successful.
--- Registration response from Cloud is parsed as input.
--- Checks request_id and status in payload before setting the register flag in config to '1'
-- @function register
-- @param inputMethod the method for register response
-- @param payload response message from Cloud
function M.register(inputMethod, lookup, payload)
  mqtt_lookup = lookup
  local logInfo = "mqttpayloadhandler ReqId: " .. (payload.requestId or "")
  log = mqtt_lookup.logger.new(logInfo, mqtt_lookup.config.logLevel)
  log:debug('Register Response received')
  local requestId = mqtt_lookup.requestId
  if inputMethod and inputMethod == "rsp" and payload and payload.requestId == requestId then
    local status
    for _, param in pairs(payload.parameters or {}) do
      status = param.status and param.status or status
    end
    if status and mqtt_lookup.mqtt_constants.registerCodes[tostring(status)] then
      mqtt_lookup.config.updateRegisterValue()
      log:info("Registration Successful!!!")
    end
  end
end

return M
