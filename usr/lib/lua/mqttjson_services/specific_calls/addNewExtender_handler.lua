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

--- Handler to notify backend, when an extender onboards sucessfully.
-- Topic for publishing this specific call is /cmd/addNewExtender
-- Gateway receives onboarding request from backend. addNewExtender handler starts listening to map_controller.agent event
-- Later RSSI param is polled at regular intervals until it reaches the timeout. The updated non-zero RSSI value is then published to backend
-- Once the event is detected, a notification(containing MAC address of extender) will be sent to backend
-- Topic for publishing the notification /event/addNewExtender
--
-- @module addNewExtender_handler
--

local proxy = require("datamodel")
local M = {}

local mqtt_lookup = {}
local log
local process = require("tch.process")
local execute = process.execute

local pollingTimer
local endPollingTimer
local mqttHandler = {}

-- Stops all the uloop timers after timeout.
local function endAllTimers()
  if pollingTimer then
    pollingTimer:cancel()
    pollingTimer = nil
  end
  endPollingTimer:cancel()
  endPollingTimer = nil
  -- restart the daemon to stop listening to the map_controller.agent event
  execute("/etc/init.d/mqttjson-services", {"reload"})
end

-- Function to get RSSI value of the extender connected.
-- rpc.multiap.device." .. mac .. ".rssi" is polled at regular intervals until it reaches the timeout. If the value of RSSI updates to a non-zero value, then a response message with Extender MAC and RSSI is published to the cloud
local function checkRSSIvalue(mac, interfaceType, connection, topic, payload)
  local RSSI = mac and proxy.get("rpc.multiap.device.@" .. mac .. ".rssi")
  if RSSI and next(RSSI) and RSSI[1].value ~= "0" then
    pollingTimer:cancel()
    pollingTimer = nil
    local rssiData = {
      requestId = payload.requestId,
      parameters  = {
        ExtenderMAC = {
          gwParameter = "ExtenderMAC",
          value = mac
        },
        ExtenderRssi = {
          gwParameter = "ExtenderRssi",
          value = RSSI[1].value
        },
        ConnectionType = {
          gwParameter = "ConnectionType",
          value = interfaceType
        }
      }
    }
    -- publish the MAC address and RSSI of the connected Extender to the backend
    mqttHandler.publish(connection, topic, rssiData)
    -- stop uloop timers after publishing the response
    endAllTimers()
  else
    pollingTimer = mqtt_lookup.uloop.timer(function() checkRSSIvalue(mac, interfaceType, connection, topic, payload) end, mqtt_lookup.config.addExtenderInterval)
  end
end

--- addNewExtender request from backend, initiates listening to "map_controller.agent" event
--- If the extender gets connected, then a response message with status code 200 is published to addNewExtender topic
-- @function getExtenderRSSI
-- @param connection table containing all the mqtt configurations required to publish
-- @param topic to which the request message is published
-- @param payload response message from Cloud
-- @param handler mqttservices_handler to facilitate publishing of messages
function M.getExtenderRSSI(lookup, payload, connection, topic, handler)
  mqtt_lookup = lookup
  mqttHandler = handler
  local logInfo = "mqttpayloadhandler ReqId: " .. (payload.requestId or "")
  log = mqtt_lookup.logger.new(logInfo, mqtt_lookup.config.logLevel)
  if not mqtt_lookup.ubusConn then
    return nil, "Failed to connect to ubusd"
  end
  topic = topic .. "addNewExtender"
  if not payload.requestId then
    log:error("The requested payload for addNewExtender does not contains 'requestId'")
    return nil
  end
  local event = {}
  --Response message should be published to cloud after receiving the addNewExtender request
  local data = {
    requestId = payload.requestId,
    status = mqtt_lookup.mqtt_constants.successCode,
    parameters = {}
  }
  --Launch WPS from the Gateway
  log:info("WPS triggred from addNewExtender_handler!")
  execute("wps_button_pressed.sh")

  event['map_controller.agent'] = function(msg)
    if msg and next(msg) and msg.ExtenderMAC and msg.state and msg.state == "Connect" then
      local mac = msg.ExtenderMAC
      log:info("A new extender of MAC address " .. mac .. " is connected!")
      local interfaceType = mac and proxy.get("rpc.multiap.device.@" .. mac .. ".backhaul_interface_type")
      interfaceType = interfaceType and next(interfaceType) and interfaceType[1].value
      local notifyData = {
        requestId = payload.requestId,
        parameters  = {
          ExtenderMAC = {
            gwParameter = "ExtenderMAC",
            value = mac
          }
        }
      }
      mqttHandler.publish(connection, topic, notifyData)
      if interfaceType and interfaceType ~= "Ethernet" then
        -- keep polling rpc parameter for RSSI at every interval configured in uci
        pollingTimer = mqtt_lookup.uloop.timer(function() checkRSSIvalue(mac, interfaceType, connection, topic, payload) end, mqtt_lookup.config.addExtenderInterval)
      elseif interfaceType == "Ethernet" then
        notifyData["parameters"]["ExtenderRssi"] = {
          gwParameter = "ExtenderRssi",
          value = "0"
        }
        notifyData["parameters"]["ConnectionType"] = {
          gwParameter = "ConnectionType",
          value = interfaceType
        }
        mqttHandler.publish(connection, topic, notifyData)
      end
      -- end all existing timers after the timeout
      endPollingTimer = mqtt_lookup.uloop.timer(function() endAllTimers() end, mqtt_lookup.config.addExtenderTimeout)
    end
  end
  mqtt_lookup.ubusConn:listen(event)
  return data
end

return M
