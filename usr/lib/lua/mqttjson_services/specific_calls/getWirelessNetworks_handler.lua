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

--- Handler to filter out backhaul interfaces.
-- Payload from this specific call is published, when receiving the request from the topic containing "/cmd/getWirelessNetworks"
-- and the config "mqttjson_services.handlers.getWirelessNetworks" is enabled.
-- the output response is framed into a table and published back to Cloud.
--
-- @module getWirelessNetworks_handler
--

local proxy = require("datamodel")
local M = {}

local mqtt_lookup = {}

local log
local utils = require("mqttjson_services.utils")
local gsub = string.gsub

--- Frames the response message of the special handler.
-- @function frameResponse
-- @param rspPayload Response message
-- @return table
local function frameResponse(rspPayload)
  for inst, parameter in ipairs(rspPayload['parameters']) do
    if parameter['$id'] then
      local isFronthaul = utils.get_path_value('uci.wireless.wifi-iface.' .. parameter['$id'] .. '.fronthaul') or ""
      if not((parameter['isGuest'] and parameter['isGuest']['value'] == '1') or isFronthaul == '1') then
        table.remove(rspPayload['parameters'], inst)
      end
    end
  end
  return rspPayload
end

--- loads the config data to the module parameters and contains a call back for framing the response.
-- @function cmd
-- @param lookup table containing config data for the module parameters
-- @param payload Request message from the cloud
-- @param inputMethod input method from topic subscribed
function M.cmd(lookup, payload, inputMethod)
  mqtt_lookup = lookup
  local rspPayload = {}
  local logInfo = "mqttpayloadhandler ReqId: " .. (payload.requestId or "")
  log = mqtt_lookup.logger.new(logInfo, mqtt_lookup.config.logLevel)
  log:debug("getWirelessNetworks handler")
  rspPayload = payload and inputMethod and mqtt_lookup.request_handler[inputMethod](mqtt_lookup, payload)
  if rspPayload then
   return frameResponse(rspPayload)
  end
end

return M
