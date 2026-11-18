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

--- Payload from the Cloud is processed to perform appropriate action.
-- The event to be notified will be requested by cloud in a request message.
-- Requested event name and parameters are stored in mqttjson_services config
-- And an acknowlodgement response is framed into a table and published back to Cloud.
--
-- @module event_handler
--

local proxy = require("datamodel")
local M = {}
local mqtt_lookup = {}

local log
local process = require("tch.process")
local execute = process.execute
local json = require("dkjson")

--- Eliminates duplicate entries present in the incoming request message as part of checkDuplicate() function
-- @function eliminateDup
-- @param list list of entries
-- @return table
local function eliminateDup(list)
  local result = {}
  local temp = {}
  for _, val in ipairs(list) do
    if not temp[val] then
      result[#result + 1] = val
      temp[val] = true
    end
  end
  return result
end

--- Compares incoming event notification condition, already present in the mqttjson_services config and returns true if duplicates are found.
-- @function checkDuplicate
-- @param reqParams table containing request parameters
-- @param eventName event name from the request
-- @return true / false
local function checkDuplicate(reqParams, eventName)
  local exist = false
  local configuredEvents = mqtt_lookup.config.getEventsFromConfig()

  for event, options in pairs(configuredEvents) do
    if event == eventName and options.parameter then
      --Iterates the conditions which are previously configured.
      local count = 0
      -- eliminates duplicate values present in a list
      reqParams = eliminateDup(reqParams)
      local uciParams = eliminateDup(options.parameter)
      if #reqParams == #uciParams then
        for _, reqVal in ipairs(reqParams) do
          for _, uciVal in ipairs(uciParams) do
            if reqVal == uciVal then
              count = count + 1
            end
          end
        end
        if #reqParams == count then
          exist = true
        else
          exist = false
        end
      end
    end
  end
  return exist
end

--- Parses the Event Notification Payload and the required data is stored in mqttjson_services config and enables the ubus listen method for the respective events to happen.
-- @function addEvents
-- @param payload contains request message from cloud
-- @param topicCommand has the command mentioned in the topic
local function addEvents(payload, topicCommand)
  local data = {}
  data.requestId = payload.requestId
  if payload["conditions"] and next(payload["conditions"]) then
    for eventName, eventData in pairs(payload.conditions or {}) do
      local uciValue = {}
      local paramValue = {}
      for reqParam, reqValue in pairs(eventData) do
        uciValue[#uciValue + 1] = reqValue and type(reqValue) == "string" and reqParam .. ":" .. reqValue or reqParam
      end
      if checkDuplicate(uciValue, eventName) then
        data.status = mqtt_lookup.mqtt_constants.addEventError
        data.error = "Event duplication"
        return data
      end
      for _, paramTable in pairs(payload.parameters or {}) do
        local gwParameter, apiParameter
        for param, val in pairs(paramTable) do
          if param == "gwParameter" then
            gwParameter = val
          elseif param == "apiParameter" then
            apiParameter = val
          end
        end
        paramValue[#paramValue + 1] = gwParameter .. ":" .. apiParameter or ""
      end
      mqtt_lookup.config.addEventInConfig(eventName, topicCommand, uciValue, paramValue)
      -- An ubus event is sent to trigger listenEvents() of event_handler
      --mqtt_lookup.ubusConn:send("mqttjson_services", { notification = "New event added", event = eventName })
      local ubus = require("ubus").connect()
      ubus:send("mqttjson_services", { notification = "New event added", event = eventName })
    end
  end

  data.status = mqtt_lookup.mqtt_constants.successCode
  return data
end

--- Parses the Event Notification Payload and the requested event is deleted and also the related data from the mqttjson_services config is removed.
-- @function deleteEvents
-- @param payload Request message from cloud
-- @param topicCommand Command mentioned in topic
function deleteEvents(payload, topicCommand)
  local data = {}
  data.requestId = payload.requestId
  local exist = mqtt_lookup.config.delEventFromConfig(topicCommand)
  if not exist then
    data.status = mqtt_lookup.mqtt_constants.delEventError
    data.error = "Non-existent event"
    return data
  end
  -- An ubus event is sent to retrigger listenEvents() of event_handler
  --mqtt_lookup.ubusConn:send("mqttjson_services", { notification = "event deleted"})
  local ubus = require("ubus").connect()
  ubus:send("mqttjson_services", { notification = "event deleted"})

  data.status = mqtt_lookup.mqtt_constants.successCode
  return data
end

--- Handles the Event notification request from the Cloud/TPS.
-- @function event_req
-- @param lookup table containing config data for the module parameter
-- @param payload contains request message from Cloud
-- @param topicCommand has the command mentioned in topic
-- @return table
-- @error Request type in the event request is not recognized
function M.event_req(lookup, payload, topicCommand)
  mqtt_lookup = lookup
  local logInfo = "mqttpayloadhandler ReqId: " .. (payload.requestId or "")
  log = mqtt_lookup.logger.new(logInfo, mqtt_lookup.config.logLevel)
  if payload and payload.type then
    if payload.type == "add" then
      return addEvents(payload, topicCommand)
    elseif payload.type == "del" then
      return deleteEvents(payload, topicCommand)
    else
      log:error("Request type in the event request is not recognized")
      local data = {}
      data.requestId = payload.requestId
      data.status = mqtt_lookup.mqtt_constants.invalidTypeError
      data.errMsg = "Request type not recognized"
    end
  end
end

return M
