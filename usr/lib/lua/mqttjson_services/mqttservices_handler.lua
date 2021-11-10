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

--- Starts the MQTT broker by setting up the connection to cloud.
-- Topics for subscribe/publish are defined.
-- Registration and API call transactions are handled here.
--
-- Registration:
--
--              - Fetches the gateway information, frames into a request message and publishes to cloud
--
--              - The response from cloud is sent to request_handler and further processed to register the device
--
--
-- Request/Response message:
--
--              - The request message from cloud is sent to request_handler to perform necessary actions
--
--              - The response message from request_handler is then published back to the corresponding topic
--
--
-- @module mqttservices_handler
--

local mqtt_lookup = {}
local json = require("dkjson")

local find, match, gsub = string.find, string.match, string.gsub
local log

-- Used to update the registration timer.
local registrationCount = 0

local registerStatus = 0
local resetTimer

local M = {}

-- Topics for Subscrption
local reqTopics = {}
local rspTopics = {}
local gwInfo = {}

--- Requires specific modules from the given path.
-- @return table
local function reqModules(features, specificCallsPath)
  local reqFeatures = {}
  for _, specificCall in pairs(features or {}) do
    if specificCall and specificCallsPath then
      local specificCallSubPath = match(specificCall, "^(%S*)(%_handler*)$")
      local specialFeature = specificCallsPath .. specificCall
      if specificCallSubPath and specialFeature then
        reqFeatures[specificCallSubPath] = require(specialFeature)
      end
    end
  end
  return reqFeatures
end

--- Frames the Device-Identifier Value based on the Device's OUI, Device's Serial Number and Device's Product Number values
-- @function getDeviceIdentifier
-- @return device identifier value
-- @error oui value not available
-- @error serial number or product number not avalilable
local function getDeviceIdentifier()
  local deviceOUI
  local cert = mqtt_lookup.x509.new_from_file(mqtt_lookup.mqtt_constants.certfile)
  if cert then
    deviceOUI = match(cert:subject(), "%CN=(%S*)%-")
  end
  if not deviceOUI then
    return nil, "oui value not available"
  end

  if not mqtt_lookup.config.envSerialNumber or not mqtt_lookup.config.envProdNumber then
    return nil, "serial number/ product number not available"
  end

  return deviceOUI .. "-" .. mqtt_lookup.config.envSerialNumber .. "-" .. mqtt_lookup.config.envProdNumber
end

--- Updates the config data to the module parameters, used for registration process.
-- @function updateGwInfo
local function updateGwInfo()
  gwInfo.requestId = mqtt_lookup.requestId
  gwInfo.parameters = {
    ["serial-number"] = mqtt_lookup.config.envSerialNumber,
    ["protocol-version"] = mqtt_lookup.mqtt_constants.protocolVersion,
    ["agent-version"] = mqtt_lookup.mqtt_constants.agentVersion,
    ["datamodel"] = mqtt_lookup.config.cwmpDatamodel,
    ["device-model"] = mqtt_lookup.config.envDeviceModel,
    ["sw-version"] = mqtt_lookup.config.swVersion,
    ["device-identifier"] = getDeviceIdentifier()
  }
end

--- Frames the required topic for the different MQTTJSON API's functionalities
-- @function updateTopics
-- @return true
-- @error Error Message from getDeviceIdentifier function
local function updateTopics()
  -- Default value for uiVersion will be 'UI-2.0'
  local uiVersion = mqtt_lookup.config.uiVersion

  -- customerTag will be Enabled/Disabled based on the uci.mqttjson_services.config.customer_name_enabled option value
  local customerTag = mqtt_lookup.config.customerNameEnabled
  local serviceIDEnabled = mqtt_lookup.config.serviceIdEnabled

  local customerName
  if customerTag == 1 then
    -- Default value for customer_name will be 'Technicolor'
    customerName = mqtt_lookup.config.customerName
  end

  local deviceID, errMsg = getDeviceIdentifier()
  if not deviceID then
    return nil, errMsg
  elseif deviceID then
    log:info("The Device Identifier value is '" .. deviceID .."'")
  end

  local serviceNameID
  -- Include '+/' to the topics, if Service_ID is enabled
  serviceNameID = (serviceIDEnabled == 1 and "+/" .. deviceID) or (serviceIDEnabled == 0 and deviceID)

  if customerName then
    -- Include CutomerName Value, if CustomerTag is enabled
    deviceID = deviceID and customerName .. "/" .. deviceID
    serviceNameID = serviceNameID and customerName .. "/" .. serviceNameID
  end

  if uiVersion then
    if deviceID then
      reqTopics.registerRsp = uiVersion .."/" .. deviceID .. "/register/rsp"
      rspTopics.registerReq = uiVersion .. "/" .. deviceID .. "/register/req"
      rspTopics.eventNotify = uiVersion .. "/" .. deviceID .. "/event/"
      rspTopics.connection = uiVersion .. "/" .. deviceID .. "/event/connection"
    end
    if serviceNameID then
      reqTopics.commandReq = uiVersion .. "/" .. serviceNameID .. "/cmd/+"
      reqTopics.authReq = uiVersion .. "/" .. serviceNameID .. "/auth/req"
      reqTopics.eventReq = uiVersion .. "/" .. serviceNameID .. "/event_req/+"
      rspTopics.commandRsp = uiVersion .. "/" .. serviceNameID .. "/rsp/"
      rspTopics.authRsp = uiVersion .. "/".. serviceNameID .. "/auth/rsp"
      rspTopics.eventRsp = uiVersion .. "/" .. serviceNameID .. "/event_rsp/"
    end
    log:debug("Topics for Subscription")
    log:debug(reqTopics.commandReq)
    log:debug(reqTopics.registerRsp)
    log:debug(reqTopics.eventReq)
    log:debug(reqTopics.authReq)
    log:debug("Format of the Topics for Publish")
    log:debug(rspTopics.commandRsp)
    log:debug(rspTopics.registerReq)
    log:debug(rspTopics.eventRsp)
    log:debug(rspTopics.eventNotify)
    log:debug(rspTopics.authRsp)
    log:debug(rspTopics.connection)
    return true
  end
end

--- Publishes mqtt json message to cloud on the specific topic
-- @function publish
-- @param connection contains information on connection URL, port, certificate details etc.,
-- @param topic mqtt topic to which the json data needs to be published
-- @param jsonJob represents the response message to cloud
-- @error Failed publishing to topic
-- @error Topic unavailable and Publish failed
function M.publish(connection, topic, jsonJob)
  if topic then
    log:debug("Response Payload is")
    log:debug(json.encode(jsonJob))
    jsonJob = jsonJob and gsub(json.encode(jsonJob), "\\n", " ")
    if connection:publish(topic, jsonJob) then
      log:info("Published to topic : %s", topic)
    else
      log:error("Failed publishing to topic : %s", topic)
    end
  else
    log:error("Topic unavailable and Publish failed")
  end
end

--- Subscribes to the relevant topic.
-- @function subscribe
-- @param connection contains information on connection URL, port, certificate etc.,
-- @error Failed subscribing
local function subscribe(connection)
  if connection:subscribe(reqTopics) then
    log:info('subscribed')
  else
    log:error('Failed subscribing')
  end
end

-- Validates the requestId in payload.
local function isValidReqId(payload)
  if payload then
    if not (type(payload.requestId) == "string") or #payload.requestId == 0 then
      return false
    end
    return true
  end
  return false
end

-- To save the connection information, and pass it on to event_handler.lua
M.notifyConnections = {}

--- Publishes the event notification messages to the cloud/TPS.
-- @function handleNotification
-- @param connection contains information on connection URL, port, certificate details etc.,
-- @param topicCommand value of the topic to be published(Eg. checkWifiStatus, newDeviceAdded)
-- @param parameters Request parameters
-- @error RequestId in event notification should be non-empty string
function M.handleNotification(connection, parameters, topicCommand)
  if parameters then
    local data = {}
    data.requestId = mqtt_lookup.requestId
    data.parameters = parameters
    local eventTopic = rspTopics.eventNotify and rspTopics.eventNotify .. topicCommand
    if eventTopic and isValidReqId(data) then
      M.publish(connection, eventTopic, data)
    elseif not isValidReqId(data) then
      log:error("RequestId in event notification should be non-empty string")
    end
  end
end

local authTopic

--- Authentication response published to Cloud.
-- @function authResponse
-- @param connection contains information on connection URL, port, certificate details etc.,
-- @param authData contains authentication response message
function M.authResponse(connection, authData)
  if authTopic and authData then
    M.publish(connection, authTopic, authData)
    authTopic = nil
  end
end

-- Generates response payload for invalid requestId error.
local function invalidReqIdResponse(payload, inputMethod)
  local response = {
    status = mqtt_lookup.mqtt_constants.generalError,
    error = "RequestId in mqtt request should be non-empty string"
  }
  if not payload then
    log:warning("Request Payload format is Incorrect")
    response.error = "Given parameter or input format is Incorrect"
    response.parameters = {}
    return response
  end
  response.requestId = payload.requestId
  if not payload.requestId then
    response.error = "No requestId in mqtt request"
  end
  if inputMethod == 'cmd' then
    response.parameters = {}
  end
  return response
end

--- Processes the incoming payload from the cloud/TPS
-- and then re-directs the respective payload to handle the request and to frame the response and sends back the response to the cloud/TPS.
-- @function processPayload
-- @param connection contains information on connection URL, port, certificate details etc.,
-- @param topic topic subscribed
-- @param payload Request message from cloud
local function processPayload(connection, topic, payload)
  local rspPayload
  local deviceIdentifier
  local registerFlag
  local inputMethod
  local rspTopic
  local topicCommand

-- To require the special behavior files from the given path.
  local specificCallsPath = mqtt_lookup.mqtt_constants.specificCallsPath
  local specificFiles = reqModules(mqtt_lookup.mqttcommon.dirWalk(specificCallsPath), specificCallsPath)

  if topic then
    if find(topic, "/register/") then
      log:info('MQTT Register Request')
      deviceIdentifier, registerFlag, inputMethod = match(topic, "^%S+%/(.+)%/(%S+)%/(%S+)$")
      rspTopic = rspTopics.registerReq
      if not isValidReqId(payload) then
        log:error("RequestId in register request should be non-empty string")
      else
        rspPayload = registerFlag and inputMethod and mqtt_lookup.registration_handler[registerFlag](inputMethod, mqtt_lookup, payload)
      end
    elseif find(topic, "/event_") then
      log:info('MQTT Event notification Request')
      deviceIdentifier, inputMethod, topicCommand = match(topic, "^%S+%/(.+)%/(%S+)%/(%S+)$")
      if inputMethod and mqtt_lookup.event_handler[inputMethod] and topicCommand then
        rspTopic = gsub(topic, "_req", "_rsp")
        rspPayload = not isValidReqId(payload) and invalidReqIdResponse(payload) or mqtt_lookup.event_handler[inputMethod](mqtt_lookup, payload, topicCommand)
      end
    elseif find(topic, "/auth/") then
      log:info('MQTT Authentication Request')
      deviceIdentifier, inputMethod, topicCommand = match(topic, "^%S+%/(.+)%/(%S+)%/(%S+)$")
      if find(topic, "/req") and inputMethod then
        rspTopic = gsub(topic, "/req", "/rsp")
        if payload then
          if payload.physicalAuthentication then
            M.notifyConnections = connection
            authTopic = rspTopic
          end
        end
        rspPayload = not isValidReqId(payload) and invalidReqIdResponse(payload) or mqtt_lookup.auth_handler[inputMethod](mqtt_lookup, payload, M)
      end
    else
      log:info('MQTT GET/SET Request')
      deviceIdentifier, inputMethod, topicCommand = match(topic, "^%S+%/(.+)%/(%S+)%/(%S+)$")
      if find(topic, "/cmd/") and inputMethod then
        rspTopic = gsub(topic, "/cmd/", "/rsp/")
        if not isValidReqId(payload) then
          rspPayload = invalidReqIdResponse(payload, inputMethod)
	elseif topicCommand and specificFiles[topicCommand] and mqtt_lookup.config.specificHandler(topicCommand) then
          rspPayload = specificFiles[topicCommand][inputMethod](mqtt_lookup, payload, inputMethod, connection, rspTopics.eventNotify, M)
        else
          rspPayload = inputMethod and mqtt_lookup.request_handler[inputMethod](mqtt_lookup, payload)
	end
      end
    end
  end

  if inputMethod == "event_req" then
    M.notifyConnections = connection
  end

  if connection and rspTopic and rspPayload then
    M.publish(connection, rspTopic, rspPayload)
  end
end

--- Checks whether registration is successful
-- If the device is not registered, then retry the registration
-- @function checkDeviceRegistered
-- @param connection contains information on connection URL, port, certificate details etc.
local function checkDeviceRegistered(connection)
  registerStatus = mqtt_lookup.config.register
  resetTimer:cancel()
  resetTimer = nil
  if registerStatus == 0 then
    log:info("Retrying registration!")
    M.gwRegistration(connection)
  end
end

--- Initiates registration.
-- Publishes the gateway information with a request_id as registration message to Cloud.
-- @function gwRegistration
-- @param connection has the mqtt configuration data
-- @error RequestId in event notification should be non-empty string
function M.gwRegistration(connection)
  if isValidReqId(gwInfo) then
    M.publish(connection, rspTopics.registerReq, gwInfo)
  elseif not isValidReqId(gwInfo) then
    log:error("RequestId in event notification should be non-empty string")
  end

  -- Wait for 15secs to receive response from TPS/Cloud and check whether the registration is successful.
  local registrationTimer = 0
  registrationTimer, registrationCount = mqtt_lookup.mqtt_client.updateTimer(registrationCount)
  if registrationTimer ~= 0 then
    log:info("Next attempt for registration will happen in %s seconds, if the device is not registered", tostring(registrationTimer))
    resetTimer = mqtt_lookup.uloop.timer(function() checkDeviceRegistered(connection) end, registrationTimer * 1000)
  end
end

--- Callback to connect to the cloud/TPS.
-- @function on_connect_cb
-- @param mqttData contains mqtt configuration related data
local function on_connect_cb(mqttData, rc, msg)
  if mqttData then
    log:info('MQTT client connected')
    if mqttData.connection then
      subscribe(mqttData.connection)
      local isRegistered = mqtt_lookup.config.register
      mqtt_lookup.ubusConn:send("mqttjson_services", { state = "connected" })
      M.notifyConnections = mqttData.connection
      if isRegistered == 1 then
        log:info("Device is already Registered!!")
        M.publish(mqttData.connection, rspTopics.connection, gwInfo)
      elseif updateTopics() and isRegistered == 0 and gwInfo.parameters["serial-number"] and gwInfo.parameters["device-model"] and gwInfo.parameters["sw-version"] then
        log:info("Initiating MQTT Registration")
        M.gwRegistration(mqttData.connection)
      end
    end
  end
end

--- Callback to disconnect from the cloud/TPS
-- @function on_disconnect_cb
-- @param mqttData contains mqtt configuration related data
local function on_disconnect_cb(mqttData, rc, msg)
  if not mqttData then
    log:info('MQTT client disconnected : %s', msg)
  end
end

--- Callback to receive the payload from the cloud/TPS.
-- @function on_message_cb
-- @param mqttData contains mqtt configuration related data
-- @param topic topic subscribed
-- @param payload Request message from cloud
-- @error Device is not registered! Hence payload cannot be processed
local function on_message_cb(mqttData, mid, topic, payload)
  log:debug("Request Payload is")
  log:debug(payload)
 local registration = mqtt_lookup.config.register
  payload = json.decode(payload)
  if mqttData and mqttData.connection and (registration and registration == 1 or find(topic, "register")) then
    -- Payload will be processed, only if the device is registered.
    processPayload(mqttData.connection, topic, payload)
  else
    log:error("Device is not registered! Hence payload cannot be processed")
  end
end

--- Frames the necessary Topic and Device-Identifier values and establishes the connection with the MQTT broker.
-- @function connect
-- @param mqttData contains mqtt configuration related data
-- @return table established mqtt connection information
-- @error Could not start MQTT Client connection, because : Error Message from updateTopic function
-- @error Could not start MQTT Client connection
function M.connect(mqttData)
  local updatedTopics, errMsg = updateTopics()
  if not updatedTopics and errMsg then
    log:error("Could not start MQTT Client connection, because : " .. tostring(errMsg))
    return
  end

  local deviceIdentifier = getDeviceIdentifier()
  local conn = deviceIdentifier and mqtt_lookup.config.logLevel and mqtt_lookup.mqtt_client.new(deviceIdentifier, mqttData.capath, mqttData.cafile, mqttData.certfile, mqttData.keyfile, mqtt_lookup.config.logLevel, mqttData.tlsEnabled, mqttData.tlskeyform, mqttData.tlsengine)

  if not conn then
    log:error("Could not start MQTT Client connection")
    return
  end

  conn:set_callback(conn.events.DISCONNECT, mqttData:bind(on_disconnect_cb))
  conn:set_callback(conn.events.CONNECT, mqttData:bind(on_connect_cb))
  conn:set_callback(conn.events.MESSAGE, mqttData:bind(on_message_cb))

  return conn
end

--- loads the config values to the module parameters.
-- @function init
-- @param lookup table containing config data for the module parameters.
function M.init(lookup)
  mqtt_lookup = lookup
  log = mqtt_lookup.logger.new("mqtthandler", mqtt_lookup.config.logLevel)
  mqtt_lookup.config.getBoardInfo()
  updateGwInfo()
end

return M
