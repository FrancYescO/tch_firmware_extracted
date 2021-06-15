-- Copyright (c) 2018 Technicolor Delivery Technologies, SAS

---
-- Encoder module to serialize the data, which has to be sent to the controller.
---

local math, string = math, string
local floor = math.floor
local char, sub = string.char, string.sub
local pairs, setmetatable, tonumber = pairs, setmetatable, tonumber
local type = type
local runtime = {}

local encodeEventToTags = {
  ["EVENT_REGISTRATION"] = {0x01},
  ["REBOOT"] = {0x0A, 0x07},
  ["GET_BASIC_INFO"] = {0x0A, 0x01},
  ["GET_BASIC_INFO_RESPONSE"] = {0x0A, 0x02},
  ["DEPLOYSOFTWARENOW"] = {0x0A, 0x03},
  ["RTFD"] = {0x0A, 0x08},
  ["GET_LED_STATUS"] = {0x0A, 0x0C},
  ["SET_LED_STATUS"] = {0x0A, 0x0E},
  ["SET_WIFI_CONFIG_REQUEST"] = {0x0A, 0x11},
  ["WIFI_DR_ONBOARDING_REQUEST"] = {0x0A, 0x13}
}

local OUI_LEN = 3
local UUID_LEN = 2
local MAC_LEN = 6
local TYPE_1905_LEN = 2
local LENGTH_1905_LEN = 4
local LENGTH_VENDOR_MSG = 2
local NUMBER_OF_AGENTS_LENGTH = 1

local Encoder = {}
Encoder.__index = Encoder

--- Encode a byte.
-- @tparam #table self A reference to a message encoder.
-- @tparam #number by A number between 0 and 255 that represents the byte.
local function encode_byte(self, by)
  local data = self.temp_data
  local data_len = self.temp_data_len
  data[#data + 1] = char(by)
  self.temp_data_len =  data_len + 1
end

--- Encode a number.
-- @tparam #table self A reference to a message encoder.
-- @tparam #number number The number to encode.
-- NOTE: The number to encode can not be larger than 65535.
local function encode_number(self, number)
  local data = self.temp_data
  local data_len = self.temp_data_len
  local hi = floor(number/256)
  local lo = number % 256
  data[#data + 1] = char(hi, lo)
  self.temp_data_len = data_len + 2
end

--- Encode a 1905 Length.
-- @tparam #table self A reference to a message encoder.
-- @tparam #number number The number to encode.
-- NOTE: The number to encode can not be larger than 2^32 -1.
local function encode_1905_length(self, number)
  local data = self.temp_data
  local data_len = self.temp_data_len
  local bin = {0, 0, 0, 0}
  for i = #bin, 1, -1 do
    bin[i] = number % 256
    number = floor(number/256)
  end
  data[#data+1] = char(unpack(bin))
  self.temp_data_len = data_len + 4
end

--- Encode a string.
-- @tparam #table self A reference to a message encoder.
-- @tparam #string str The string to encode.
-- NOTE: The length of the given string can not exceed 65535. This limit is imposed by
--       the usage of the encode_number function.
local function encode_string(self, str)
  local s_len = #str
  encode_1905_length(self, s_len)
  local data = self.temp_data
  local data_len = self.temp_data_len
  data[#data + 1] = str
  self.temp_data_len = data_len + s_len
end

--- Encode the hex input of n size.
-- @tparam #table self A reference to a message encoder.
-- @tparam #string hex The hex input to be encoded.
-- @tparam #number len Length of the hex input to be encoded.
-- NOTE: To work fine length should be given as a even number
local function encode_hex(self, hex, len)
  local i = 1
  while i <= len do
    encode_byte(self, tonumber(sub(hex, i, i+1), 16))
    i = i + 2
  end
end

local function can_use_hard_limit(self)
  return self.data_len > self.soft_size or self.first_encoding --hard limit already in use
end

--- Does the new temp data fit into the maximum buffer
-- @tparam #table self A reference to the message encoder
local function temp_data_fits(self)
  local new_length = self.data_len + self.temp_data_len
  if new_length <= self.soft_size then
    return true
  elseif can_use_hard_limit(self) and new_length <= self.hard_size then
    return true
  end
  return false
end

--- Drop the temporary data
-- @tparam #table self A reference to the message encoder
local function temp_data_reset(self)
  self.temp_data = {}
  self.temp_data_len = 0
end

--- Make the temp data permanent
-- @tparam #table self A reference to the message encoder
local function temp_data_append(self)
  local data = self.data
  local data_len = self.data_len
  local temp_len = self.temp_data_len
  local temp_data = self.temp_data
  for _, value in ipairs(temp_data) do
    data[#data + 1] = value
  end
  self.data_len = data_len + temp_len
  self.first_encoding = false
end

--- Finalize the encoding
-- @tparam #table self A reference to the message encoder
-- @treturn true if the new data was added, false if the new data
--   could not fit in the maximum buffer size
local function confirm_encoding(self)
  local data_fits = temp_data_fits(self)
  if data_fits then
    temp_data_append(self)
  end
  temp_data_reset(self)
  return data_fits
end

local function getTableCount(tbl)
  local no_of_events = 0
  for _, _ in pairs(tbl) do
    no_of_events = no_of_events + 1
  end
  return no_of_events
end

--- Encodes a Event registration message consisting of the events to be registered in controller.
-- @tparam #table events_to_be_registered A table with event type as key and event data as value
function Encoder:EVENT_REGISTRATION(events_to_be_registered)
  runtime.log:info("Encoding event registration message")
  local hexpattern2 = "%02X"
  local hexpattern4 = "%08X"
  local no_of_events = getTableCount(events_to_be_registered)
  local len = (5 * no_of_events) + 1
  encode_number(self, len)
  encode_byte(self, no_of_events)
  for eventType, data in pairs(events_to_be_registered) do
    encode_hex(self, hexpattern2:format(eventType), 2)
    encode_hex(self, hexpattern4:format(data), 8)
  end
  return confirm_encoding(self)
end

--- Encodes a 1905 message consisting of mac, oui and vendor specific data.
-- @tparam #string mac The agent mac to be encoded.
-- @tparam #string oui The OUI ID of the vendor to be encoded.
-- @tparam #string uuid Unique ID of multicast message.
-- @tparam #string data_1905 The vendor specific data to be encoded.
function Encoder:SEND_1905_DATA(mac, oui, uuid, data_1905)
  runtime.log:info("Encoding 1905 message")
  local len_1905 =  TYPE_1905_LEN + LENGTH_1905_LEN + #data_1905
  local totalLen =  OUI_LEN + UUID_LEN + MAC_LEN + LENGTH_VENDOR_MSG + len_1905 + NUMBER_OF_AGENTS_LENGTH
  local hexpattern = "%04X"
  encode_number(self, totalLen)
  encode_hex(self, uuid, 4)
  encode_hex(self, oui, 6)
  encode_byte(self, 1)
  encode_hex(self, mac, 12)
  encode_number(self, len_1905)
  runtime.log:info("TLV type of 1905 message is " .. encodeEventToTags[self.current_tag][2])
  encode_hex(self, hexpattern:format(encodeEventToTags[self.current_tag][2]), 4)
  encode_string(self, data_1905)
  return confirm_encoding(self)
end

--- Encodes 1905 messages consisting of oui, agent data and total tlv length for multiple agents.
-- @tparam #string oui The OUI ID of the vendor to be encoded.
-- @tparam #string uuid Unique ID of multicast message.
-- @tparam #table agent_data A table containing agents and its tlv data.
-- @tparam #number total_tlv_length The total length of the tlv data json message for all agents.
function Encoder:SEND_1905_MESSAGE_TO_MULTIPLE_AGENTS(oui, uuid, agent_data, total_tlv_length)
  runtime.log:info("Encoding 1905 messages for multiple agents")
  local no_of_agents = getTableCount(agent_data)
  runtime.log:info("No of agents %d", no_of_agents)
  local len_var =  (TYPE_1905_LEN + LENGTH_1905_LEN + MAC_LEN + LENGTH_VENDOR_MSG) * no_of_agents + NUMBER_OF_AGENTS_LENGTH + total_tlv_length
  local totalLen =  len_var + OUI_LEN + UUID_LEN
  runtime.log:info("Total length %d", totalLen)
  local hexpattern = "%04X"
  encode_number(self, totalLen)
  encode_hex(self, uuid, 4)
  encode_hex(self, oui, 6)
  encode_byte(self, no_of_agents)
  for agentMac, agentData in pairs(agent_data) do
    agentMac = string.gsub(agentMac, ":", "")
    encode_hex(self, agentMac, 12)
    encode_number(self, #agentData + TYPE_1905_LEN + LENGTH_1905_LEN)
    runtime.log:info("TLV length %d", #agentData)
    encode_hex(self, hexpattern:format(encodeEventToTags[self.current_tag][2]), 4)
    encode_string(self, agentData)
    runtime.log:info("TLV data %s", agentData)
  end
  return confirm_encoding(self)
end

local function encoder_set_max_size(self, max_size)
  local soft, hard
  if type(max_size) == 'table' then
    soft = max_size[1]
    hard = max_size[2] or soft
  else
    soft = max_size
    hard = max_size
  end
  if soft and soft > 0 and soft <= hard then
    self.soft_size = soft
    self.hard_size = hard
    return true
  end
end

---
-- Initialize the encoder environment to encode messages of the given tag.
-- @tparam #string tag The tag of the message we wish to encode.
-- @tparam #number max_size The maximum size of a single message. This is either a single number
--   or a table with two numbers {soft, hard} with the soft limit and a hard limit.
--   The soft limit is the normal maximum, The hard limit is only used when the first
--   item is encoded to allow for exceptional cases.
-- NOTE: This function MUST be called before encode()
-- can be used.
function Encoder:init_encode(tag, max_size)
  self.data = {}
  self.data_len = 0
  self.temp_data = {}
  self.temp_data_len = 0
  runtime.log:info("Intializing message encoder")
  if not encodeEventToTags[tag] then
    runtime.log:error("Encoding failed: Tag value unknown")
    return false
  end
  encode_byte(self, encodeEventToTags[tag][1])
  if not encoder_set_max_size(self, max_size) then
    return false
  end
  local r = confirm_encoding(self)
  if r then
    self.first_encoding = true
  end
  self.current_tag = tag
  return r
end

function Encoder:retrieve_data()
  return self.data
end

local M = {}

M.init = function(rt)
  runtime  = rt
end

M.new = function()
  local self = {
    -- An array to which the encodings should be added.
    data = {},
    -- The total length of the data currently in the 'data' table.
    data_len = 0,
    -- The maximum allowed length for the data.
    soft_size = 0,
    -- The maximum allowed size for the first encoding. This may be larger
    -- to be able to handle exceptional cases
    hard_size = 0,
    -- A temporary array that contains data we wish to add to the encoding.
    temp_data = {},
    -- The length of the new data.
    temp_data_len = 0,
    -- is this the first encoding after init_encode()
    first_encoding = false
  }
  return setmetatable(self, Encoder)
end

return M
