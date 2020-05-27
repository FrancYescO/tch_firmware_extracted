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

--- Mqttjson_services config parameters are loaded.
-- Default values for the config parameters are initialised.
--
-- @module mqttservices_config
--

local M = {}
local mqttConfig = "mqttjson_services"
local uci

local defaults = {
  enabled = 0,
  tlsEnabled = 0,
  tlsKeyform = "engine:keystore",
  tlsCerts = "/etc/ssl/certs:/proc/rip/011a.cert:/proc/keys/0x11A",
  certLocation = "/etc/mqttjson_services/certs/",
  connectionUrl = "",
  connectionPort = "8883",
  logLevel = 5,
  uiVersion = "UI-2.0",
  customerName = "Technicolor",
  customerNameEnabled = 0,
  serviceIdEnabled = 0,
  getTimeOut = 1,
  getDeviceList = 1,
  ignorePhysicalAuth = 0,
  register = 0,
  requestId = "",
  backoffMinwait = 5,
  backoffMultiplier = 2000,
  addExtenderInterval = 5000,
  addExtenderTimeout = 120000,
}

function M.getConfig(uciCursor)
  uci = uciCursor
  M.enabled = tonumber(uci:get(mqttConfig, 'config', 'enabled')) or defaults.enabled
  M.logLevel = tonumber(uci:get(mqttConfig, 'config', 'log_level')) or defaults.logLevel
  M.tlsEnabled = uci:get(mqttConfig, 'config', 'tls_enabled') or defaults.tlsEnabled
  M.tlsKeyform = uci:get(mqttConfig, 'config', 'tls_keyform') or defaults.tlsKeyform
  M.tlsCerts = uci:get(mqttConfig, 'config', 'tls_certs') or defaults.tlsCerts
  M.certLocation = uci:get(mqttConfig, 'config', 'cert_location') or defaults.certLocation
  M.connectionUrl = uci:get(mqttConfig, 'config', 'connection_url') or defaults.connectionUrl
  M.connectionPort = uci:get(mqttConfig, 'config', 'connection_port') or defaults.connectionPort
  M.uiVersion = uci:get(mqttConfig, 'config', 'ui_version') or defaults.uiVersion
  M.customerName = uci:get(mqttConfig, 'config', 'customer_name') or defaults.customerName
  M.customerNameEnabled = tonumber(uci:get(mqttConfig, 'config', 'customer_name_enabled')) or defaults.customerNameEnabled
  M.serviceIdEnabled = tonumber(uci:get(mqttConfig, 'config', 'service_id_enabled')) or defaults.serviceIdEnabled
  M.getDeviceList = tonumber(uci:get(mqttConfig, 'config', 'get_device_list') or defaults.getDeviceList)
  M.getTimeOut = tonumber(uci:get(mqttConfig, 'config', 'get_timeout_list') or defaults.getTimeOut)
  M.ignorePhysicalAuth = tonumber(uci:get(mqttConfig, 'config', 'ignore_physical_auth')) or defaults.ignorePhysicalAuth
  M.backoffMinwait = tonumber(uci:get(mqttConfig, 'registration', 'backoff_minwait')) or defaults.backoffMinwait
  M.backoffMultiplier = tonumber(uci:get(mqttConfig, 'registration', 'backoff_multiplier')) or defaults.backoffMultiplier
  M.register = tonumber(uci:get(mqttConfig, "registration", "register")) or defaults.register
  M.requestId = uci:get(mqttConfig, 'registration', 'request_id') or defaults.requestId
  M.addExtenderInterval = tonumber(uci:get(mqttConfig, 'add_new_extender', 'interval')) or defaults.addExtenderInterval
  M.addExtenderTimeout = tonumber(uci:get(mqttConfig, 'add_new_extender', 'timeout')) or defaults.addExtenderTimeout
end

function M.updateRegisterValue()
  uci:set(mqttConfig, "registration", 'register', "1")
  uci:commit(mqttConfig)
  M.register = tonumber(uci:get(mqttConfig, 'registration', 'register'))
end

function M.addEventInConfig(eventName, topicCommand, uciValue, paramValue)
  local section = uci:add(mqttConfig, "notification")
  uci:set(mqttConfig, section, "event", eventName)
  uci:set(mqttConfig, section, "topicCommand", topicCommand)
  uci:set(mqttConfig, section, "parameter", uciValue)
  uci:set(mqttConfig, section, "gwParam", paramValue)
  uci:commit(mqttConfig)
end

function M.delEventFromConfig(topicCommand)
  local exist = false
  uci:foreach(mqttConfig, function(s)
    if (s and s["topicCommand"] and s["topicCommand"] == topicCommand) then
      uci:delete(mqttConfig, s['.name'])
      exist = true
    end
  end)
  uci:commit(mqttConfig)
  return exist
end

function M.getEventsFromConfig()
  local configuredEvents = {}
  uci:foreach(mqttConfig, function(s)
    if s and s.event then
      configuredEvents[s.event] = {
        parameter = s.parameter,
        gwParameter = s.gwParam,
        topicCommand = s.topicCommand
      }
    end
  end)
  return configuredEvents
end

return M
