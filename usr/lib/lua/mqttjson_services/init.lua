#!/usr/bin/lua

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

--- Initialization of MQTT Protocol and Service.
-- Parameters required for setting up the connection are initialised.
--
-- @module init
--

local mqtt_lookup = {}
mqtt_lookup.uci = require('uci')
mqtt_lookup.uloop = require('uloop')
mqtt_lookup.ubus = require('ubus')
mqtt_lookup.cursor = mqtt_lookup.uci.cursor()
mqtt_lookup.ubusConn = mqtt_lookup.ubus.connect()
mqtt_lookup.logger = require("tch.logger")

mqtt_lookup.config = require('mqttjson_services.mqttservices_config')
mqtt_lookup.mqtt_client = require('mqttjson_services.mqtt_client')
mqtt_lookup.service_handler = require('mqttjson_services.mqttservices_handler')
mqtt_lookup.event_listener = require('mqttjson_services.event_listner')
mqtt_lookup.auth_handler = require('mqttjson_services.authentication_handler')
mqtt_lookup.event_handler = require('mqttjson_services.event_handler')
mqtt_lookup.registration_handler = require('mqttjson_services.registration_handler')
mqtt_lookup.req_response_handler = require('mqttjson_services.reqResponse_handler')
mqtt_lookup.utils = require('mqttjson_services.utils')
mqtt_lookup.mqtt_constants = require('mqttjson_services.mqttAPIconstants')
mqtt_lookup.mqttcommon = require('mqttjson_services.mqttcommon_handler')
mqtt_lookup.requiredDatamodels = require('mqttjson_services.requiredDatamodels')
mqtt_lookup.requestId = mqtt_lookup.mqttcommon.getRandomKey()

local log
local match = string.match
local M = {}

local mqttjson_service = {
  bind = require('mqttjson_services.bind')
}

--- Initializes MQTT service by framing the connection information.
-- @function init
-- @return true
function mqttjson_service:init()
  log:info("Proceeding with initialization")
  self.tlsEnabled = mqtt_lookup.config.tlsEnabled
  local tlsKeyform = mqtt_lookup.config.tlsKeyform
  if tlsKeyform then
    self.tlskeyform, self.tlsengine = match(tlsKeyform, "^(%S+)%:(%S+)$")
  end
  if self.tlsEnabled == "1" then
    local tlsCerts = mqtt_lookup.config.tlsCerts
    if tlsCerts then
      self.capath, self.certfile, self.keyfile = match(tlsCerts, "^(%S+)%:(%S+)%:(%S+)$")
      self.cafile = self.capath and self.capath .. "/ca-certificates.crt"
    end
  else
    certlocation = mqtt_lookup.config.certLocation
    self.capath = certlocation
    self.cafile = self.capath and self.capath .. 'root.ca'
    self.certfile = certlocation and certlocation .. 'certfile.pem'
    self.keyfile = certlocation and certlocation .. 'keyfile.pem.key'
  end
  self.connectionurl = mqtt_lookup.config.connectionUrl
  self.connectionport = mqtt_lookup.config.connectionPort
  if self.capath and self.cafile and self.certfile and self.keyfile and self.connectionurl and self.connectionport and self.tlsEnabled then
    self.connection = mqtt_lookup.service_handler.connect(self)
    if self.connection then
      log:debug("Connection Succeeded")
      return true
    end
  end
end

--- Starts the MQTT service, with the connectionURL and connectionPort pointing to Cloud.
-- @function start
function mqttjson_service:start()
  log:debug("Starting MQTT Client connection")
  self.connection:start(self.connectionurl, self.connectionport)
  -- mqtt_lookup.event_listener is triggered to run on a uloop
  mqtt_lookup.event_listener.start(mqtt_lookup)
  mqtt_lookup.uloop.run()
end

function M.loadModule()
  mqtt_lookup.config.getConfig(mqtt_lookup.cursor)
  log = mqtt_lookup.logger.new("mqttjsonserviceslog", mqtt_lookup.config.logLevel)
  mqtt_lookup.uloop.init()
  mqtt_lookup.utils.init(mqtt_lookup)
  mqtt_lookup.mqtt_client.init(mqtt_lookup)
  mqtt_lookup.service_handler.init(mqtt_lookup)
  if mqttjson_service:init() then
    mqttjson_service:start()
    os.exit(0)
  else
    log:error("Failed to initialize mqttjson service")
    os.exit(1)
  end
end

return M
