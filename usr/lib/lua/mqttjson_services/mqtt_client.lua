#!/usr/bin/lua
---------------------------------------------------------------------------
-- Copyright (c) 2016 Technicolor
-- All Rights Reserved
--
-- This program contains proprietary information which is a trade
-- secret of TECHNICOLOR and/or its affiliates and also is protected as
-- an unpublished work under applicable Copyright laws. Recipient is
-- to retain this program in confidence and is not permitted to use or
-- make copies thereof other than as permitted in a written agreement
-- with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS.
---------------------------------------------------------------------------

-- Script contains definition of mqtt client functions


------------------------------------------------------
-- EXTERNAL DATA
------------------------------------------------------
local mosquitto = require("mosquitto")
local bit = require("bit")

-- Enable logger
local logger = require('tch.logger')
local mqttclilog = logger.new("mqttclilog", 5)
--mqttclilog:set_log_level(5) -- (1 lowest, 6 highest) (1=critical, 2=error, 3=warning, 4=notice, 5=info, 6=debug)


mqttclilog.logger_cb = function(mqttclilog, log_level, label)
    return function(message)
        mqttclilog[log_level](mqttclilog, ('Mosquitto client [%s] %s'):format(label, tostring(message)))
    end
end

local MIN_KEEPALIVE_SECONDS = 120
local MAX_KEEPALIVE_SECONDS = 1200

-- General stuff
local M = {}
mosquitto.init()

-- MqTT Client base class
MqttClient = {
    -- Member "variables"
    host = 'localhost',
    port = 1883,

    subscriptions = {},
    qos = 1,

    -- On-connection data
    is_connected = false,
    on_connect_ctx = {
        reconnect = false,
        user_cb = nil,
        timer = nil
    },

    -- uloop data
    uloop = nil,
    uloop_ctx = {
        fd = nil,
        timer = nil,
        fd_handler = nil,
        timer_handler = nil,
    },

    -- Constants
    CONNECT_RETRY_INTERVAL_MS = 120000,
    KEEPALIVE_SECONDS = 30,
    MAX_IDLE_TIME_MS = 20000,

    -- MQTT events constants
    events = {
        CONNECT     = 'ON_CONNECT',
        DISCONNECT  = 'ON_DISCONNECT',
        PUBLISH     = 'ON_PUBLISH',
        MESSAGE     = 'ON_MESSAGE',
        SUBSCRIBE   = 'ON_SUBSCRIBE',
        UNSUBSCRIBE = 'ON_UNSUBSCRIBE',
        LOG         = 'ON_LOG'
    },

    mosq_log_levels_cbs = {
        [1]   = mqttclilog:logger_cb('info', 'INFO'),
        [2]   = mqttclilog:logger_cb('notice', 'NOTICE'),
        [4]   = mqttclilog:logger_cb('warning', 'WARNING'),
        [8]   = mqttclilog:logger_cb('error', 'ERR'),
        [16]  = mqttclilog:logger_cb('debug', 'DEBUG'),
        [32]  = mqttclilog:logger_cb('debug', 'SUBSCRIBE'),
        [64]  = mqttclilog:logger_cb('debug', 'UNSUBSCRIBE'),
        [128] = mqttclilog:logger_cb('debug', 'WEBSOCKETS'),
        ['unknown'] = mqttclilog:logger_cb('warning', 'UNKNOWN'),
    },

    log_level = 255,

    -- Member "methods"
    bind = require('mqttjson_services.bind')
}

-- Simple utility function to check if a string is empty
local function isempty(str)
    if str == nil or str == '' then
        return true
    end

    return false
end

-- Simple utility function to check if a file exists
local function file_exists(filename)
    if isempty(filename) then
        return false
    end

    local res = false
    local file = io.open(filename)
    if file then
        res = true
        io.close(file)
    end

    return res
end

-- Create a new instance of mqtt client
function M.new(uloop, client_id, capath, cafile, certfile, keyfile, log_level)
    local self = {}
    setmetatable(self, {__index = MqttClient})

    mqttclilog:set_log_level(log_level)
    mqttclilog:debug("client " .. client_id .. " capath " .. capath .. " cafile " .. cafile .. " certfile " .. certfile .. " keyfile " .. keyfile)

    self.uloop = uloop

    if isempty(client_id) then
        mqttclilog:error('No MQTT client ID')
        return nil
    end

    self.client = mosquitto.new(client_id, true)
    if not self.client then
        mqttclilog:error('Failed creating MQTT client')
        return nil
    end

    if file_exists(capath) and file_exists(certfile) and file_exists(keyfile) then
        self.client:tls_set(cafile, capath, certfile, keyfile)
    else
        if not file_exists(capath) then
            mqttclilog:error('root CA path was not specified')
        end
        if not file_exists(certfile) then
            mqttclilog:error('Could not find ' .. certfile)
        end
        if not file_exists(keyfile) then
            mqttclilog:error('Could not find ' .. keyfile)
        end

        return nil
    end

    self.uloop_ctx.fd_handler = self:bind(self.fd_handler_cb)
    self.uloop_ctx.timer_handler = self:bind(self.timer_handler_cb)
    self:set_callback(self.events.LOG, self:bind(self.on_log_cb))

    return self
end

--Function to update the keepalive time
function MqttClient:update_keepalive_time()
    mqttclilog:debug('MQTT: Update Keep alive time')
    --TBD
end

-- When connecting, we first want to stop "reconnect_handler"
-- from retrying to connect, by setting "is_connected" to true
function MqttClient:on_connect_cb(success, rc, msg)
    mqttclilog:debug('MQTT: Recieved connect message')
    self.is_connected = true

    if self.on_connect_ctx.user_cb then
        self.on_connect_ctx.user_cb(success, rc, msg)
    end
end

function MqttClient:on_disconnect_cb(success, rc, msg)
    if not self.is_connected then
        return
    end

    mqttclilog:info('Disconnection detected [%s]', tostring(msg))

    self:uloop_cleanup()

    self.is_connected = false
    self.subscriptions = {} -- subscriptions list is not relevant anymore
    self.on_connect_ctx.timer:set(10) -- now

    if self.on_disconnect_user_cb then
        self.on_disconnect_user_cb(success, rc, msg)
    end
end

-- A callback for showing mosquitto client' library inner logs
function MqttClient:on_log_cb(level, msg)
    if bit.band(self.log_level, level) == 0 then
        return
    end

    log_cb = self.mosq_log_levels_cbs[level] or mosq_log_levels_cbs['unknown']
    log_cb(msg)
end

-- Set callback for the misc events
-- event:    One constant from self.events.
-- callback can be:
-- 1. on_connect:
--    func(success, rc, msg), where:
--      * success: boolean
--      * rc:      c return code
--      * msg:     string, verbose response
-- 2. on_disconnect:
--    func(success, rc, msg), where:
--      * success: boolean
--      * rc:      c return code
--      * msg:     string, verbose response
-- 3. on_message:
--    func(mid, topic, payload, qos, retain), where:
--      * mid:      message id
--      * topic:    valid MqTT topic
--      * payload:  the accepted mesaage
--      * qos:      quality of service (0-2)
--      * retain:   should message be retained
-- 4. on_publish:
--    func(mid), where:
--      * mid: message id
--
function MqttClient:set_callback(event, callback)
    local _callback = nil
    if event == self.events.CONNECT then
        self.on_connect_ctx.user_cb = callback
        _callback = self:bind(self.on_connect_cb)
    elseif event == self.events.DISCONNECT then
        self.on_disconnect_user_cb = callback
        _callback = self:bind(self.on_disconnect_cb)
    else
        _callback = callback
    end

    if _callback then
        self.client:callback_set(event, _callback)
    else
        mqttclilog:error('Cannot assign nil callback to an mqtt event');
    end
end

-- Wrapper for fd registration
function MqttClient:register_fd(flags)
    if self.uloop_ctx.fd then
        self.uloop_ctx.fd:delete()
    end
    self.uloop_ctx.fd = self.uloop.fd_add(self.client:socket(), self.uloop_ctx.fd_handler, flags)
end

-- U-Loop events handlers
function MqttClient:fd_handler_cb(ufd, events)
    if not ufd then
        return
    end

    if bit.band(events, self.uloop.ULOOP_WRITE) == self.uloop.ULOOP_WRITE then
        self.client:loop_write()
        if not self.client:want_write() then
            self:register_fd(self.uloop.ULOOP_READ)
        end
    end

    if self.client:want_write() and (bit.band(events, self.uloop.ULOOP_WRITE) == 0) then
        self:register_fd(bit.bor(self.uloop.ULOOP_READ, self.uloop.ULOOP_WRITE))
        self.uloop.timer(function() self.uloop_ctx.fd_handler(ufd, self.uloop.ULOOP_WRITE) end, 10) -- "now"
    end
    if bit.band(events, self.uloop.ULOOP_READ) == self.uloop.ULOOP_READ then
        self.client:loop_read()
    end
end

function MqttClient:timer_handler_cb()
    self.client:loop_misc()
    -- loop_misc can trigger on_disconnect that invalidates the timer
    if not self.is_connected then
        return
    end
    self.uloop_ctx.timer:set(self.MAX_IDLE_TIME_MS)
end

function MqttClient:will_set(willtopic, willpayload)
    local res = self.client:will_set(willtopic, willpayload, self.qos, false)
    if not res then
        mqttclilog:error('Error in setting the will...')
    else
        mqttclilog:debug('successful in setting the will...')
    end
end

function MqttClient:reconnect_handler_cb()
    if self.is_connected then
        return
    end

    self:connect()
    self.on_connect_ctx.timer:set(self.CONNECT_RETRY_INTERVAL_MS)
end

function MqttClient:connect()
    local r
    if not self.on_connect_ctx.reconnect then
        mqttclilog:debug('Trying to connect to MQTT broker...')
        mqttclilog:debug('host ' .. self.host .. ' port ' .. self.port)
--	self.update_keepalive_time(self) TBD
        r = self.client:connect(self.host, self.port, self.KEEPALIVE_SECONDS)
    else
        mqttclilog:debug('Trying to reconnect to MQTT broker...')
        r = self.client:reconnect()
    end
    if not r then
        mqttclilog:error('Error connecting to MQTT broker ' .. self.host .. ':' .. self.port)
        return false
    end

    -- After the first successful "connectd, we need to
    -- execute "reconnect" if the connection fails/disconnects
    self.on_connect_ctx.reconnect = true

    if not self.client:socket() then
        mqttclilog:error('Could not retrieve MQTT socket');
        return false
    end

    local flags = bit.tobit(self.uloop.ULOOP_READ)
    -- After "reconnect", mosquitto might have someting to write
    -- (Not probable after "connect")
    if self.client:want_write() then
        flags = bit.bor(flags, self.uloop.ULOOP_WRITE)
    end
    self:register_fd(flags)

    if self.client:want_write() then
        self.uloop_ctx.fd_handler(self.client:socket(), self.uloop.ULOOP_WRITE)
    end

    -- Mosquitto "housekeeping" handler
    self.uloop_ctx.timer = self.uloop.timer(self.uloop_ctx.timer_handler, self.MAX_IDLE_TIME_MS)

    return true
end

function MqttClient:uloop_cleanup()
    if  self.uloop_ctx.timer then
        self.uloop_ctx.timer:cancel()
    end
    if self.uloop_ctx.fd then
        self.uloop_ctx.fd:delete()
    end
end

-- Start communication with the broker
function MqttClient:start(host, port)
    if self.is_connected then
        mqttclilog:warning('Trying to run an already-running MQTT client')
        return true
    end

    if not self.on_connect_ctx.user_cb then
        mqttclilog:error('ON_CONNECT handler not set')
        return false
    end

    if not self.on_disconnect_user_cb then
        mqttclilog:error('ON_DISCONNECT handler not set')
        return false
    end

    self.host = host or self.host
    self.port = port or self.port
    self.on_connect_ctx.timer = self.uloop.timer(self:bind(self.reconnect_handler_cb), 10)

    return true
end

-- Stop communication with the broker
function MqttClient:stop()
    if not self.is_connected then
        mqttclilog:warning('Warning: Trying to stop a disconnected MQTT client')
        return
    end

    if self.on_connect_ctx.timer then
      self.on_connect_ctx.timer:cancel()
    end

    self:uloop_cleanup()

    if self.client then
--      self.client:disconnect()
    end

    self.is_connected = false
end

-- Publish to a topic
function MqttClient:publish(topic, payload)
    local res = self.client:publish(topic, payload, self.qos,false)

    if not res then
        mqttclilog:error('Failed publishing to ' .. topic)
        return false
    end

    self.uloop_ctx.fd_handler(self.client:socket(), self.uloop.ULOOP_WRITE)

    return res
end

-- Subscribe to a topic
function MqttClient:subscribe(topics)
    local res = true

    for _, v in pairs(topics) do
        mqttclilog:debug('Subscribing to ' .. v);
        table.insert(self.subscriptions, v)
        res = self.client:subscribe(v, self.qos)
        if not res then
            mqttclilog:error('Failed subscribing to ' .. v)
            break
        end
    end

    self.uloop_ctx.fd_handler(self.client:socket(), self.uloop.ULOOP_WRITE)

    return res
end

-- Remove all subscriptions
function MqttClient:unsubscribe_all()
    for _, topic in pairs(self.subscriptions) do
        self.client:unsubscribe(topic)
    end
    self.subscriptions = {}

    self.uloop_ctx.fd_handler(self.client:socket(), self.uloop.ULOOP_WRITE)
end

return M
