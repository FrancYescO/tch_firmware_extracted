-- Copyright (c) 2018 Technicolor Delivery Technologies, SAS

---
-- Common module to initialize both encoder and decoder functions.
---

local require, setmetatable = require, setmetatable
local runtime = {}

local msg_encode = require("vendorextensions.msg_encode")
local msg_decode = require("vendorextensions.msg_decode")

-- The supported Encode events.
local EVENT_REGISTRATION = "EVENT_REGISTRATION"
local REBOOT = "REBOOT"
local GET_BASIC_INFO = "GET_BASIC_INFO"
local GET_BASIC_INFO_RESPONSE = "GET_BASIC_INFO_RESPONSE"
local DEPLOYSOFTWARENOW = "DEPLOYSOFTWARENOW"
local RTFD = "RTFD"
local GET_LED_STATUS = "GET_LED_STATUS"
local SET_LED_STATUS = "SET_LED_STATUS"
local SET_WIFI_CONFIG_REQUEST = "SET_WIFI_CONFIG_REQUEST"

-- The supported Decode events.
local AGENT_ONBOARD = 2
local AGENT_OFFBOARD = 3
local AGENT_UPDATE = 4
local STA_CONNECT = 5
local STA_DISCONNECT = 6
local DATA_1905_AVAILABLE = 7
local STA_METRICS = 8
local AP_METRICS = 9
local MULTICAST_STATUS = 11

-------------------------------------------------------------
-- Module that can serialize and deserialize data
--
-- Messages start with a tag byte indicating which type of
-- message it is.
--
-- What follows the tag byte is dependent on the tag.
-- Numbers are typically encoded as two bytes
-- in big endian order. Strings are encoded as the length
-- of the string as two bytes in big endian order,
-- followed by the actual string data. This data is NOT
-- necessarily zero terminated.
-------------------------------------------------------------
local Msg = {}
Msg.__index = Msg

-- Encode

function Msg:init_encode(tag, max_size)
  self.current_tag = tag
  return self.msg_encoder:init_encode(tag, max_size)
end

---
-- Encodes the given values in the given table as a
-- message of the given tag.
-- If there's already data present in 'data' then it
-- will be added at the end.
-- Returns the number of bytes added to 'data'. When
-- an invalid tag is given 0 will be returned and the
-- state of 'data' is undefined.
-- NOTE: This will only work correctly if init_encode was
--       called first.
function Msg:encode(...)
  if self.encoders[self.current_tag] then
    return self.encoders[self.current_tag](self.msg_encoder, ...)
  end
  runtime.log:error("Tag %s, has no encoder function", self.current_tag)
  return false
end

function Msg:retrieve_data()
  return self.msg_encoder:retrieve_data()
end

-- Decode

function Msg:init_decode(msg)
  local tag = self.msg_decoder:init_decode(msg)
  self.current_tag = tag
  return tag
end

---
-- Decode the given message.
-- NOTE: This will only work correctly if init_decode was
--       called first.
function Msg:decode()
  if self.decoders[self.current_tag] then
    return self.decoders[self.current_tag](self.msg_decoder)
  end
end

-- Load the encoder functions.
-- returns a lookup table with encode tags and its encoder functions.
local function load_encoder_functions(encoder)
  return {
    [REBOOT] = encoder.SEND_1905_DATA,
    [EVENT_REGISTRATION] = encoder.EVENT_REGISTRATION,
    [GET_BASIC_INFO] = encoder.SEND_1905_DATA,
    [GET_BASIC_INFO_RESPONSE] = encoder.SEND_1905_DATA,
    [DEPLOYSOFTWARENOW] = encoder.SEND_1905_MESSAGE_TO_MULTIPLE_AGENTS,
    [RTFD] = encoder.SEND_1905_DATA,
    [GET_LED_STATUS] = encoder.SEND_1905_DATA,
    [SET_LED_STATUS] = encoder.SEND_1905_DATA,
    [SET_WIFI_CONFIG_REQUEST] = encoder.SEND_1905_MESSAGE_TO_MULTIPLE_AGENTS,
  }
end

-- Load the decoder functions.
-- returns a lookup table with decode tags and its decoder functions.
local function load_decoder_functions(decoder)
  return {
    [AGENT_ONBOARD] = decoder.AGENT_ONBOARD,
    [AGENT_OFFBOARD] = decoder.AGENT_OFFBOARD,
    [AGENT_UPDATE] = decoder.AGENT_ONBOARD,
    [STA_CONNECT] = decoder.STA_CONNECT,
    [STA_DISCONNECT] = decoder.STA_DISCONNECT,
    [DATA_1905_AVAILABLE] = decoder.DATA_1905_AVAILABLE,
    [STA_METRICS] = decoder.STA_METRICS,
    [AP_METRICS] = decoder.AP_METRICS,
    [MULTICAST_STATUS] = decoder.MULTICAST_STATUS,
  }
end

-- The maximum size of a socket buffer
local MAX_NOMINAL_BUFFER = 32*1024 --32K

---
-- Get the proper size to init encoding
-- This will limit the maximum size of a packet to 32K bytes
-- proper usage is:
--     local max_size = msg.softLimit(uds.MAX_DGRAM_SIZE)
--     msg:init_encode(tag, max_size)
-- @tparam #number sz Maximum size of the packet
function Msg.softLimit(sz)
  if sz > MAX_NOMINAL_BUFFER then
    return {MAX_NOMINAL_BUFFER, sz}
  end
  return sz
end

local M = {}

M.init = function(rt)
  runtime  = rt
  msg_encode.init(rt)
  msg_decode.init(rt)
end

M.new = function()
  local encoder = msg_encode.new()
  local decoder = msg_decode.new()
  local self = {
    msg_encoder = encoder,
    msg_decoder = decoder,
    current_tag = nil,
    encoders = load_encoder_functions(encoder),
    decoders = load_decoder_functions(decoder),
  }
  return setmetatable(self, Msg)
end

return M
