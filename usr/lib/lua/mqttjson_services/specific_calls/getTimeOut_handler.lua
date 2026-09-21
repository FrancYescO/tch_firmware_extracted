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

--- Handler to produce the response about the WiFi-TOD details.
-- Payload from this specific call is published, when receiving the request from the topic containing "/cmd/getTimeout"
-- and the config "mqttjson_services.handlers.getTimeOut" is enabled.
-- The output response is framed into a table and published back to Cloud.
--
-- @module getTimeOut_handler
--

local proxy = require("datamodel")
local M = {}
local mqtt_lookup = {}
local log
local gsub = string.gsub

--- loads the parameters field for the response message.
-- @function addParameterValue
-- @param gwParameter request parameter
-- @param value value of the requested parameter
-- @return table
local function addParameterValue(gwParameter, value)
  local param = {}
  param['gwParameter'] = gwParameter
  param['value'] = value
  return param
end

--- Frames the response message of the special handler.
-- @function frameResponse
-- @param payload Request message from cloud
-- @return table
local function frameResponse(payload)
  -- Move the system time to each object
  local result = {}
  local parameters = {}
  local dmData = {}
  local result = {}
  local parameters = {}
  result.status = mqtt_lookup.mqtt_constants.successCode
  result.parameters = parameters
  result.requestId = payload and payload.requestId and payload.requestId
  result.status = mqtt_lookup.mqtt_constants.successCode
  result.parameters = parameters
  result.requestId = payload and payload.requestId and payload.requestId

  local wifitodList, wifitodListerrMsg = mqtt_lookup.utils.get_instance_list('uci.tod.wifitod.') -- Returns list of wifitod

  if wifitodListerrMsg then
    result.error = wifitodListerrMsg or "Given parameter or input format is Incorrect"
    result.status = mqtt_lookup.mqtt_constants.generalError
    return result
  end

  for _, wifitodInst in pairs(wifitodList or {}) do
    local device = {}
    local apTodValuePath = wifitodInst .. "ap.@1.value"
    local apTodValue, errMsg = mqtt_lookup.utils.get_path_value(apTodValuePath)
    local id = apTodValuePath:gsub('uci.tod.wifitod.', '')
    id = id:gsub(".ap.@1.value", "")
    device['$id'] = id
    device['wifitod_name'] = addParameterValue(apTodValuePath, apTodValue)
    local apTodSubPath = 'uci.tod.ap.@'
    local apTodState = apTodSubPath ..  apTodValue .. '.state'
    device['ap_state'] = addParameterValue(apTodState, mqtt_lookup.utils.get_path_value(apTodState))
    local apTodSsid = apTodSubPath ..  apTodValue .. '.ssid'
    device['ap_ssid'] = addParameterValue(apTodSsid, mqtt_lookup.utils.get_path_value(apTodSsid))
    local apTodAp = apTodSubPath .. apTodValue .. '.ap'
    device['access_point'] = addParameterValue(apTodAp, mqtt_lookup.utils.get_path_value(apTodAp))
    parameters[ #parameters + 1 ] = device
  end
  result['parameters'] = parameters
  return result
end

--- loads the config data to the module parameters and contains a call back for framing the response
-- @function cmd
-- @param lookup table containing config data for the module parameters
-- @param payload Request message from cloud
function M.cmd(lookup, payload)
  mqtt_lookup = lookup
  local logInfo = "mqttpayloadhandler ReqId: " .. (payload.requestId or "")
  log = mqtt_lookup.logger.new(logInfo, mqtt_lookup.config.logLevel)
  log:debug("getTimeoutList handler")
  return frameResponse(payload)
end

return M
