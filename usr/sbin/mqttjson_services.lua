#!/usr/bin/lua
---------------------------------------------------------------------------
-- Copyright (c) 2018 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.
---------------------------------------------------------------------------

-- Script connects to specified AWS IOT Thing
-- Receives an MQTT Messages which contains the TR069 datamodel parameter
-- Sends an MQTT Message response of the specified TR069 datamodel parameter
-- The TR069 datamodel parameter can be IGD or Device2 datamodel.
-- The script is derived from the existing orchestra agent.

------------------------------------------------------
-- EXTERNAL DATA
------------------------------------------------------
local json   = require("dkjson") -- JSON module used by Web API
local proxy  = require("datamodel")
local uci    = require('uci')
local ubus   = require('ubus')
local mqtt   = require('mqttjson_services.mqtt_client')
local common = require('mqttjson_services.utils')
local process= require('tch.process')
local xpcall = require('tch.xpcall')

local uci_cursor = uci.cursor()

local log_level = tonumber(uci_cursor:get('mqttjson_services','debug','log_level'))
-- Enable logger
local logger = require('tch.logger')
local mqttjsonserviceslog = logger.new("mqttjsonserviceslog" , log_level)
local format = string.format

local mqttjson_service = {
  uloop   = require('uloop'),
  bind    = require('mqttjson_services.bind'),
  connectionurl = nil,
  connectionport = nil,
  capath    =  nil,
  cafile    =  nil,
  certfile  =  nil,
  keyfile   =  nil,
  awsconn   = nil,
  timer = nil,
}

local topics = {}
local serial = uci_cursor:get('mqttjson_services','config','myThing_Name')
if not serial then
  mqttjsonserviceslog:error("Error getting serial, EXITING...")
  return
end
table.insert(topics,serial.."/cmd")



------------------------------- Function Defs  ------------------------------------

function mqttjson_service:on_connect_cb(success, rc, msg)
  mqttjsonserviceslog:info('MQTT client connected')
  self:sub()
  self:updateTopicInShadow()
end

function mqttjson_service:on_disconnect_cb(success, rc, msg)
  mqttjsonserviceslog:info('MQTT client disconnected' .. ' msg ' .. msg)
end

function mqttjson_service:on_message_cb(mid,topic, payload)
  mqttjsonserviceslog:debug(payload)
  self:process_payload(payload)
end


function mqttjson_service:errorhandler(err)
  mqttjsonserviceslog:error(err)
end


function mqttjson_service:init()
  self.uloop.init()
  mqttjsonserviceslog:info("Proceeding with initialization")
  self.client_id = serial
  certlocation   = uci_cursor:get('mqttjson_services','config','cert_location')
  self.capath    = certlocation
  self.cafile    = self.capath .. 'root.ca'
  self.certfile  = certlocation .. 'certfile.pem'
  self.keyfile   = certlocation .. 'keyfile.pem.key'
  self.connectionurl = uci_cursor:get('mqttjson_services','config','connection_url')
  self.connectionport = uci_cursor:get('mqttjson_services','config','connection_port')
  self.client_id = self.client_id
  self.awsconn = mqtt.new(self.uloop, self.client_id, self.capath, self.cafile, self.certfile, self.keyfile, log_level)
  if not self.awsconn then
    mqttjsonserviceslog:error("Could not start MQTT Client ")
    return nil
  end

  self.awsconn:set_callback(self.awsconn.events.DISCONNECT, self:bind(self.on_disconnect_cb))
  self.awsconn:set_callback(self.awsconn.events.CONNECT, self:bind(self.on_connect_cb))
  self.awsconn:set_callback(self.awsconn.events.MESSAGE, self:bind(self.on_message_cb))
  return self
end


function mqttjson_service:start()
  self.awsconn:start(self.connectionurl, self.connectionport)
  xpcall(self.uloop.run, errorhandler)
end

------------------------------- PUBLISH SUBSCRIBE ------------------------------------
function mqttjson_service:pub(jsonJob)
  local encode = json.encode(jsonJob)

  --    TODO: The IOT thing 'myThing_East_1' is created in AWS IOT for POC purpose.
  --          In productization, for each and every device there shall be a unique
  --          thing to be created. Then the thing name shall be the device 'serial'
  --          number.
  --          Hence, the below publish line with 'myThing_East_1' shall be obsolete
  --          in productization and shall be updated with the thing_shadow in publish.
  --
  --    NOTE: To make POC work then thing_shadow_path in /etc/config/mqttjson-services
  --          shall be manually configured with "$aws/things/myThing_East_1/shadow/update"
  --
  --    local res = self.awsconn:publish("$aws/things/myThing_East_1/shadow/update", encode)

  local thing_shadow = uci_cursor:get('mqttjson_services','config','thing_shadow_path')
  local res = self.awsconn:publish(thing_shadow, encode)

  if not res then
    mqttjsonserviceslog:error('Failed publishing')
  else
    mqttjsonserviceslog:info("published")
  end
end

function mqttjson_service:sub()
  local res = self.awsconn:subscribe(topics)
  if not res then
    mqttjsonserviceslog:error('Failed subscribing')
  else
    mqttjsonserviceslog:info('subscribed')
  end
end

------------------------------- Update Topic In Shadow --------------------------------

function mqttjson_service:updateTopicInShadow()
  mqttjsonserviceslog:info('UPDATE TOPIC IN SHADOW serial = ', serial)

  local add_myTopic = {}
  add_myTopic['myTopic'] = serial.."/cmd"

  local shadow_data = {}
  shadow_data['reported'] = add_myTopic

  local json_string = {}
  json_string['state'] = shadow_data
  self:pub(json_string)
end

-----------------------------------------------------------------------

-- function to process the given input command
-- @commandArgs is a table which contains key and ucicommandlist
-- i.e : {"key": "WiFi", "ucicommandlist": ["set uci.wireless.wifi-ap.@ap2.state 0", "get uci.wireless.wifi-ap.@ap2.state", "set uci.wireless.wifi-ap.@apx.state 0", "get uci.wireless.wifi-ap.@apx.state"]}
function mqttjson_service:process_command(commandArgs)
  local temp_job = {}
  local getresult = {}
  local success
  -- To process set operation
  for _, data in pairs(commandArgs.ucicommandlist) do
    local action, path = data:match("(%S+)%s+(%S+)%s*")
    -- To process set operation
    if action == "set" and proxy.get(path) then
      local value = data:match("(%S+)$")
      if value then
        success = proxy.set(path, value)
      end
    end
  end
  if success then
    proxy.apply()
  end
  -- To process get operation
  for _, data in pairs(commandArgs.ucicommandlist) do
    local action, path = data:match("(%S+)%s+(%S+)%s*")
    -- To process get operation
    local getPath = proxy.get(path)
    if action == "get" and getPath and getPath[1].value then
      getresult[path] = getPath[1].value
    end
  end
  if next(getresult) then
    temp_job[commandArgs.key] = getresult
  end
  local add_Event1 = {}
  add_Event1.Event = temp_job

  local shadow_data = {}
  shadow_data.reported = add_Event1

  local json_string = {}
  json_string.state = shadow_data
  self:pub(json_string)
end

function mqttjson_service:getHostList(commandArgs)
  local temp_job = {}
  local getresult = {}
  for _, data in pairs(commandArgs.ucicommandlist) do
    local action, path = data:match("(%S+)%s+(%S+)%s*")
    if action == "get" then
      local host_list = proxy.get(path)
      for index, data1 in pairs(host_list) do
        if data1.param == "FriendlyName"  or data1.param == "MACAddress" or data1.param == "State" then
          getresult[data1.path..data1.param] = data1.value
        end
      end
    end
  end
  temp_job[commandArgs.key] =   getresult
  local add_Event1 = {}
  add_Event1.Event = temp_job

  local shadow_data = {}
  shadow_data.reported = add_Event1

  local json_string = {}
  json_string.state = shadow_data
  self:pub(json_string)
end


--Generate random key for new rule
--@return 16 digit random key.
function getRandomKey()
  local bytes
  local key = ("%02X"):rep(16)
  local fd = io.open("/dev/urandom", "r")
  if fd then
    bytes = fd:read(16)
    fd:close()
  end
  return key:format(bytes:byte(1, 16))
end

-- function to create rule to block the internet access for given device.
function mqttjson_service:createRule_IndividualDevice(_payload, key)
  local uniqueKey = getRandomKey()
  local oldrule = proxy.get("uci.tod.host.")
  if next(oldrule) then
    for i, v in pairs(oldrule) do
      if v.param == "id" then
        if string.lower(v.value) == string.lower(_payload.mac) then
          proxy.del(v.path)
          proxy.apply()
        end
      end
    end
  end

  if _payload.state == "block" then
    local addedIndex = proxy.add("uci.tod.host.",uniqueKey)
    setTable= {}
    setTable[format("uci.tod.host.@%s.enabled", addedIndex)] = "1"
    setTable[format("uci.tod.host.@%s.rule_name", addedIndex)] = ""
    setTable[format("uci.tod.host.@%s.type", addedIndex)] = "mac"
    setTable[format("uci.tod.host.@%s.start_time", addedIndex)] = "00:00"
    setTable[format("uci.tod.host.@%s.stop_time", addedIndex)] = "23:59"
    setTable[format("uci.tod.host.@%s.id", addedIndex)] = _payload.mac
    setTable[format("uci.tod.host.@%s.mode", addedIndex)] = _payload.state
    proxy.set(setTable)
    proxy.apply()
  end

  t = {}
  temp_job = {}

  t[_payload.mac] = _payload.state
  temp_job[key] =  t
  local add_Event1 = {}
  add_Event1.Event = temp_job

  local shadow_data = {}
  shadow_data.reported = add_Event1

  local json_string = {}
  json_string.state = shadow_data
  self:pub(json_string)
end

-- function to create rule to block the internet access for All connected device.
function mqttjson_service:createlRule_ForAllConnectedDevice(_payload, key)
  local oldrule = proxy.get("uci.tod.host.")
  local hostlist = proxy.get("rpc.hosts.host.")
  if next(oldrule) then
    proxy.del("uci.tod.host.")
    proxy.apply()
  end
  if key == "InternetDisable" then
    if next(hostlist) then
      setTable= {}
      for i, v in pairs(hostlist) do
        if v.param == "MACAddress" then
          local uniqueKey = getRandomKey()
          local addedIndex = proxy.add("uci.tod.host.",uniqueKey)
          setTable[format("uci.tod.host.@%s.enabled", addedIndex)] = "1"
          setTable[format("uci.tod.host.@%s.rule_name", addedIndex)] = ""
          setTable[format("uci.tod.host.@%s.type", addedIndex)] = "mac"
          setTable[format("uci.tod.host.@%s.start_time", addedIndex)] = "00:00"
          setTable[format("uci.tod.host.@%s.stop_time", addedIndex)] = "23:59"
          setTable[format("uci.tod.host.@%s.id", addedIndex)] = v.value
          setTable[format("uci.tod.host.@%s.mode", addedIndex)] =   _payload.state
        end
      end
      proxy.set(setTable)
      proxy.apply()
    end
  end
  temp_job = {}
  temp_job["Internet"] =  key
  temp_job["InternetAccess"] = {}

  local add_Event1 = {}
  add_Event1.Event = temp_job

  local shadow_data = {}
  shadow_data.reported = add_Event1

  local json_string = {}
  json_string.state = shadow_data
  self:pub(json_string)
end

function mqttjson_service:doUnSubscription(key, command, name)
  local args ={}
  for index, _ in string.gmatch(command, "[^%s]+") do
    args[#args+1] = index
  end
  local unsubscribeDone = false
  local id
  local result = process.popen("lcm", args)
  if result then
    local output = result:read("*all")
    id = string.match(output, "[^ID:%s]+")
    if id then
      unsubscribeDone = true
    end
  end
  if unsubscribeDone == true then
    local temp_job = {}
    temp_job[name] = { appid = "", value = key }

    local add_Event1 = {}
    add_Event1.Event = temp_job

    local shadow_data = {}
    shadow_data.reported = add_Event1

    local json_string = {}
    json_string.state = shadow_data
    self:pub(json_string)
  end
end

function mqttjson_service:doSubscription(key, command, name)
  local args ={}
  for index, _ in string.gmatch(command, "[^%s]+") do
    args[#args+1] = index
  end
  local result = process.popen("lcm", args)
  local subscribeDone = false
  local id
  if result then
    local output = result:read("*all")
    id = string.match(output, "[^ID:%s]+")
    if id then
       process.popen("lcm", {"start", "ID="..id})
       os.execute("sleep 2")
       local lcmlist = process.popen("lcm", {"list", "ID="..id})
       if lcmlist then
         output = lcmlist:read("*all")
         state = string.match(output, "state:%s+(%a+)")
         if state == "running" then
           subscribeDone = true
         end
       end
    end
  end
  if subscribeDone == true then
    local temp_job = {}
    temp_job[name] = { appid = id, value = key }

    local add_Event1 = {}
    add_Event1.Event = temp_job

    local shadow_data = {}
    shadow_data.reported = add_Event1

    local json_string = {}
    json_string.state = shadow_data
    self:pub(json_string)
  end
end


-- function to process given command based on the intent key.
function mqttjson_service:process_payload(payload)
  local _payload = json.decode(payload)
  -- To get the default show to APP page load
  if _payload.key == "getPageLoadinfo" then
    for i, v in pairs(_payload.ucicommandlist) do
      if v.key == "WiFi" or v.key == "Firewallmode" then
        self:process_command(v)
      elseif v.key == "getDeviceInfo" then
        self:getHostList(v)
      end
    end
  -- To create a rule for given mac
  elseif _payload.key == "InternetAccess" then
    self:createRule_IndividualDevice(_payload.ucicommandlist, _payload.key)
  -- To create a rule for all connected devices
  elseif _payload.key == "InternetDisable" or _payload.key == "InternetEnable" then
    self:createlRule_ForAllConnectedDevice(_payload.ucicommandlist, _payload.key)
  elseif _payload.key == "Subscribe" then
    self:doSubscription(_payload.key, _payload.command, _payload.appname)
  elseif _payload.key == "UnSubscribe" then
    self:doUnSubscription(_payload.key,_payload.command, _payload.appname)
  else
    -- To process the given set/get command
    self:process_command(_payload)
  end
end

--------------------------- CREATE GUEST NETWORK ---------------------------

function mqttjson_service:create_guest_network(jsonPayload)
    local ssidPath = "uci.wireless.wifi-iface.@wl0_2.ssid"
    local pskPath  = "uci.wireless.wifi-ap.@ap3.wpa_psk_key"
    local statePath = "uci.wireless.wifi-iface.@wl0_2.state"

    local ssidres, ssiderr = common.set_path_value(ssidPath, jsonPayload['SSID'])
    if not ssidres then
        mqttjsonserviceslog:error('Failed setting ssid path "' .. ssidPath .. '": ' .. ssiderr[1].errmsg)
        return false
    end

    local pskres, pskerr = common.set_path_value(pskPath, jsonPayload['PSK'])
    if not pskres then
        mqttjsonserviceslog:error('Failed setting psk path "' .. pskPath .. '": ' .. pskerr[1].errmsg)
        return false
    end

    local stateres, stateerr = common.set_path_value(statePath, "1")
    if not stateres then
        mqttjsonserviceslog:error('Failed setting state path "' .. statePath .. '": ' .. stateerr[1].errmsg)
        return false
    end

    res, err = common.apply()
    if not res then
        mqttjsonserviceslog:error('Failed apply: ' .. err[1].errmsg)
        return false
    end

    mqttjsonserviceslog:info('Command successfully executed')
    local temp_job = {}
    temp_job['GUEST_SSID'] = jsonPayload['SSID']
    temp_job['GUEST_PSK'] = jsonPayload['PSK']
    temp_job['SERIAL'] = serial
    self:pub(temp_job)
end

------------------------------- Execution starts here ------------------------------------

retval = mqttjson_service:init()
if not retval then
  logger:error("Failed to initialize mqttjson service")
  return nil
end
retval = mqttjson_service:start()

mqttjsonserviceslog:info('EXITED')

self.uloop.run()
