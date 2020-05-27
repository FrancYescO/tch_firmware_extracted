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
--              - The response from cloud is sent to reqResponse_handler and further processed to register the device
--
--
-- Request/Response message:
--
--              - The request message from cloud is sent to reqResponse_handler to perform necessary actions
--
--              - The response message from reqReponse_handler is then published back to the corresponding topic
--
--
-- @module mqttservices_handler
--

local mqtt_lookup = {}
local json = require("dkjson")
local specialCalls = require("mqttjson_services.specificCalls_handler")

local find, match, gsub, lower = string.find, string.match, string.gsub, string.lower
local log

local count = 0
local registerStatus = 0
local resetTimer

local M = {}

-- Topics for Subscrption
local reqTopics = {}
local rspTopics = {}
local gwInfo = {}

--- Function to require specific modules from the given path.
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

-- Returns the Device Identifier value
local function getDeviceIdentifier()
  local deviceOUI = mqtt_lookup.cursor:get('env', 'var', 'oui')
  if not deviceOUI then
    return nil, "oui value not available"
  end

  local serial = mqtt_lookup.cursor:get('env', 'var', 'serial')
  if not serial then
    return nil, "serial number not available"
  end

  local productNumber = mqtt_lookup.cursor:get('env', 'var', 'prod_number')
  if not productNumber then
    return nil, "prod_number value not available"
  end

  return deviceOUI .. "-" .. serial .. "-" .. productNumber
end

local function updateGwInfo()
  gwInfo.requestId = mqtt_lookup.requestId
  gwInfo.parameters = {
    ["serial-number"] = mqtt_lookup.cursor:get("env.var.serial"),
    ["protocol-version"] = mqtt_lookup.mqtt_constants.protocolVersion,
    ["agent-version"] = mqtt_lookup.mqtt_constants.agentVersion,
    ["datamodel"] = mqtt_lookup.cursor:get("cwmpd.cwmpd_config.datamodel") or "InternetGatewayDevice",
    ["device-model"] = mqtt_lookup.cursor:get("env.var.prod_friendly_name"),
    ["sw-version"] = mqtt_lookup.cursor:get("version.@version[0].version"),
    ["device-identifier"] = getDeviceIdentifier()
  }
end

-- Updates topics if uiVersion and deviceOUI config values are available
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

--- Publishes mqtt json message to cloud
-- @function publish
-- @param connection contains information on connection URL, port, certificate details etc.,
-- @param topic mqtt topic to which the json data needs to be published
-- @param jsonJob represents the response message to cloud
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
local function subscribe(connection)
  if connection:subscribe(reqTopics) then
    log:info('subscribed')
  else
    log:error('Failed subscribing')
  end
end

-- To save the connection information, and pass it on to event_handler.lua
M.notifyConnections = {}

--- Ubus data along with connection information from event_handler.lua is passed to handleNotification().
-- The response is then framed and published to Cloud.
-- @function handleNotification
-- @param connection contains information on connection URL, port, certificate details etc.,
-- @param topicCommand value of the topic to be published(Eg. checkWifiStatus, newDeviceAdded)
function M.handleNotification(connection, parameters, topicCommand)
  if parameters then
    local data = {}
    data.requestId = mqtt_lookup.requestId
    data.parameters = parameters
    local eventTopic = rspTopics.eventNotify and rspTopics.eventNotify .. topicCommand
    if eventTopic then
      M.publish(connection, eventTopic, data)
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

-- Processes the API Commands
-- Sends payload data to respective reqResponse handler functions
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
      rspTopic = reqTopics.registerRsp
      rspPayload = registerFlag and inputMethod and mqtt_lookup.registration_handler[registerFlag](inputMethod, mqtt_lookup, payload)
    elseif find(topic, "/event_") then
      log:info('MQTT Event notification Request')
      deviceIdentifier, inputMethod, topicCommand = match(topic, "^%S+%/(.+)%/(%S+)%/(%S+)$")
      if inputMethod and mqtt_lookup.event_handler[inputMethod] and topicCommand then
        rspTopic = gsub(topic, "_req", "_rsp")
        rspPayload = mqtt_lookup.event_handler[inputMethod](mqtt_lookup, payload, topicCommand)
      end
    elseif find(topic, "/auth/") then
      log:info('MQTT Authentication Request')
      deviceIdentifier, inputMethod, topicCommand = match(topic, "^%S+%/(.+)%/(%S+)%/(%S+)$")
      if find(topic, "/req") then
        rspTopic = gsub(topic, "/req", "/rsp")
        if payload.physicalAuthentication then
          M.notifyConnections = connection
          authTopic = rspTopic
        end
        rspPayload = inputMethod and mqtt_lookup.auth_handler[inputMethod](mqtt_lookup, payload, M)
      end
    else
      log:info('MQTT GET/SET Request')
      deviceIdentifier, inputMethod, topicCommand = match(topic, "^%S+%/(.+)%/(%S+)%/(%S+)$")
      if find(topic, "/cmd/") then
        rspTopic = gsub(topic, "/cmd/", "/rsp/")
	if topicCommand and specificFiles[topicCommand] and specialCalls.features[lower(topicCommand)] and (not(mqtt_lookup.config[topicCommand]) or mqtt_lookup.config[topicCommand] == 1) then
          rspPayload = specificFiles[topicCommand][specialCalls.features[lower(topicCommand)]](mqtt_lookup, payload, connection, rspTopics.eventNotify, M)
        else
          rspPayload = inputMethod and mqtt_lookup.req_response_handler[inputMethod](mqtt_lookup, payload)
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

-- Function to check whether registration is successful
-- If the device is not registered, then retry the registration
local function checkDeviceRegistered(connection)
  registerStatus = mqtt_lookup.config.register
  resetTimer:cancel()
  resetTimer = nil
  if registerStatus == 0 then
    log:info("Retrying registration!")
    M.gwRegistration(connection)
  end
end

-- Function to update retry timer value for registration, based on back-off mechanism.
-- Backoff mechanism deals with retry sessions, when registration is not successful. It makes additional registration requests in an exponential fashion.
-- Count value to align with uloop.timer() which will handle maximum of 10 intervals.
local function updateTimer()
  local backoff_minwait = mqtt_lookup.config.backoffMinwait
  local backoff_multiplier = mqtt_lookup.config.backoffMultiplier
  if backoff_minwait and backoff_multiplier and count then
    local timer = (backoff_minwait * (backoff_multiplier/1000)^(count + 1)) - (backoff_minwait * (backoff_multiplier/1000)^count)
    if count < 9 then
      count = count + 1
    end
    if timer then
      log:info("Next attempt for registration will happen in %s seconds, if the device is not registered", tostring(timer))
      return timer * 1000
    end
  end
end

--- Function to initiate registration.
-- Publishes the gateway information with a request_id as registration message to Cloud.
-- @function gwRegistration
-- @param connection has the mqtt configuration data
function M.gwRegistration(connection)
  M.publish(connection, rspTopics.registerReq, gwInfo)

  -- Wait for 15secs to receive response from TPS/Cloud and check whether the registration is successful.
  resetTimer = mqtt_lookup.uloop.timer(function() checkDeviceRegistered(connection) end, updateTimer())
end

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

-- Disconnecting Call Backs
local function on_disconnect_cb(mqttData, rc, msg)
  if not mqttData then
    log:info('MQTT client disconnected : %s', msg)
  end
end

-- Message in Call Back
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

--- Establish connection to MQTT client
-- @function connect
-- @param mqttData - contains mqtt configuration related data
-- @return #table established mqtt connection information
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

function M.init(lookup)
  mqtt_lookup = lookup
  log = mqtt_lookup.logger.new("mqtthandler", mqtt_lookup.config.logLevel)
  updateGwInfo()
end

return M
