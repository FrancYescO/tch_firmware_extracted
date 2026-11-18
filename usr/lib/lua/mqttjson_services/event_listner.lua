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

--- Supports notification of events for changes detected(only requested changes).
--
-- Event notification works for scenarios like:
--
--    1. When a new device has joined the network.
--
--    2. Guest WiFi on/off.
--
--    3. Enable/Disable internet.
--
--
-- These updates are taken based on the ubus events.
-- The event to be notified will be requested by cloud in a request message.
-- If the expected event occurs in HGW, a response message would be constructed and sent to TPS.
--
-- @module event_listner
--

local mqtt_lookup = {}
local log
local conn = require('ubus').connect()
local match = string.match
local proxy = require("datamodel")

local M = {}

-- Saves macAddress of devices, which ever is/was connected to the gateway.
local macTable = {}

-- Contains list of events, which mqttjson_services module is listening to.
local totalEvents = {}

--- Stores the connected device list, at the initialisation of the MQTT Module.
-- @function updateDeviceList
-- @error "Error fetching list"
local function updateDeviceList()
  local path = 'sys.hosts.host.'
  local hostList = mqtt_lookup.utils.get_instance_list(path)
  for _, host in pairs(hostList or {}) do
    local macExist = false
    local macAddress, errMsg = proxy.get(host .. "MACAddress")
    if not errMsg and macAddress and macAddress[1] and macAddress[1].value then
      macAddress = macAddress[1].value
    else
      log:error("Error fetching " .. path .. " list")
      return
    end
    for _, macList in pairs(macTable) do
      if macAddress and macList == macAddress then
        macExist = true
        break
      end
    end
    if not macExist then
      -- Populate MAC address of all connected devices into macTable
      log:debug("New device with a MAC Address of " .. macAddress .. " is added to the macTable.")
      macTable[#macTable + 1] = macAddress
    end
  end
end

--- fetches event notification data from the mqttjson_services config, and listens to the corresponding events.
-- @function listenEvents
local function listenEvents()
  -- connection information fetched from mqttservices_handler
  local connection = mqtt_lookup.service_handler.notifyConnections

  local configuredEvents = mqtt_lookup.config.getEventsFromConfig()
  for eventName, eventValues in pairs(configuredEvents or {}) do
    local events = {}
    local eventDuplicate = false
    for _, name in pairs(totalEvents) do
      if name == eventName then
        eventDuplicate = true
        break
      else
        eventDuplicate = false
      end
    end
    if not eventDuplicate then
      events[eventName] = function(msg)
        configuredEvents = mqtt_lookup.config.getEventsFromConfig()
        if configuredEvents[eventName] then
          local parameters = {}
          local requiredParam = {}
          local gwParameters = {}
          local exactEvent = false
          for _, mac in pairs(macTable or {}) do
            -- If the topic command is "getNewDevice" and newly connected device's MAC matches with the available MAC address present in macTable then notification shouldn't be sent.
            if msg["mac-address"] and msg["mac-address"] == mac and eventValues.topicCommand == "getNewDevice" then
              return
            end
          end
          for _, list in ipairs(eventValues.parameter or {}) do
            if string.find(list, ":") then
              local param, value = match(list, "^(%S*)%:(%S*)")
              if param and value then
                requiredParam[param] = value
              end
            else
              requiredParam[list] = match(list, "^%S*%:(%S*)") or ""
            end
          end
          for param, value in pairs(requiredParam or {}) do
            if param and value and msg[param] and ((value ~= "" and msg[param] == value) or (value == "" and msg[param])) then
              exactEvent = true
            else
              exactEvent = false
              break
            end
          end
          for _, list in pairs(eventValues.gwParameter or {}) do
            if string.find(list, ":") and exactEvent then
              local gwParam, apiParam = match(list, "^(%S*)%:(%S*)")
              if gwParam and apiParam and msg[gwParam] then
                gwParameters[apiParam] = {
                  gwParameter = gwParam,
                  value = msg[gwParam]
                }
                exactEvent = true
              else
                exactEvent = false
                break
              end
            end
          end
          if eventName == "network.neigh" then
            -- To keep an update of connected devices in macTable
            updateDeviceList()
          end
          parameters[#parameters + 1] = gwParameters and next(gwParameters) and gwParameters
          if exactEvent and parameters and next(parameters) and eventValues.topicCommand then
            -- Sends data from ubus event to mqttservices_handler(where the request is framed and published to cloud)
            mqtt_lookup.service_handler.handleNotification(connection, parameters, eventValues.topicCommand)
          end
        end
      end
      totalEvents[#totalEvents + 1] = eventName
      conn:listen(events)
    end
  end
end

--- Starts to listen the Events available in the mqttjson_services config at the initialisation of MQTT module.
-- @function start
-- @param lookup table containing config data for the module parameter
function M.start(lookup)
  mqtt_lookup = lookup
  log = mqtt_lookup.logger.new('mqtt-events', mqtt_lookup.config.logLevel)

  if not conn then
    return nil, "Failed to connect to ubusd"
  end
  local mqttEvent = {}
  mqttEvent['mqttjson_services'] = function(msg)
    if msg then
      listenEvents()
    end
  end
  -- Save MAC address of devices whenever the module starts/restarts
  updateDeviceList()
  conn:listen(mqttEvent)
end

return M
