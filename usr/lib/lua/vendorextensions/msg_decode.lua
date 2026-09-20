-- Copyright (c) 2018 Technicolor Delivery Technologies, SAS

---
-- Decoder module to deserialize the incoming data form the controller.
---

local string = string
local setmetatable = setmetatable
local byte = string.byte
local sub = string.sub
local runtime = {}

local Decoder = {}
Decoder.__index = Decoder

--- Decode a byte.
-- @tparam #table self A reference to a message decoder.
-- @treturn #number A number between 0 and 255 that represents the decoded byte.
local function decode_byte(self)
  local message = self.message
  local index = self.index
  local decodedByte = byte(message, index)
  self.index = index + 1
  return decodedByte
end

--- Decode a number.
-- @tparam #table self A reference to a message decoder.
-- @return #number The decoded number. The number is expected
--                 to be big endian encoded.
local function decode_number(self)
  local message = self.message
  local index = self.index
  local hi, lo = byte(message, index, index + 1)
  local value = (hi * 256) + lo
  self.index = index + 2
  return value
end

--- Decode 1905 message length.
-- @tparam #table self A reference to a message decoder.
-- @treturn #number The decoded number. The number is expected
--                 to be big endian encoded.
local function decode_1905_length(self)
  local message = self.message
  local index = self.index
  local hihi, hilo, lohi, lolo = byte(message, index, index + 3)
  local value = (hihi * 2^24) + (hilo * 2^16) + (lohi * 2^8) + lolo
  self.index = index + 4
  return value
end

--- Decode a string.
-- @tparam #table self A reference to a message decoder.
-- @tparam #function decode_length Function to be called to decode the length of string.
-- @treturn #string The decoded string.
local function decode_string(self, decode_length)
  local length = decode_length(self)
  local message = self.message
  local index = self.index
  -- Note: if we're decoding an empty string then the msg
  -- only contains the two length bytes (which are zero).
  -- In that case we call sub() with 'idx' and 'idx - 1'
  -- which happens to return an empty string. That's what
  -- we want but it isn't officially documented that that's
  -- the behavior.
  local value = sub(message, index, index + length - 1)
  self.index = index + length
  return value
end

local hexpattern = "%02X"

--- Decode a hexadecimal value.
-- @tparam #table self A reference to a message decoder.
-- @tparam #integer len Length in bytes
-- @treturn #string String representation of decoded hexadecimal value.
local function decode_hex(self, len)
  local val = ""
  local i = 1
  while i <= len do
    local decodedByte = decode_byte(self)
    val = val .. hexpattern:format(decodedByte)
    i = i + 1
  end
  return val
end

--- Initialize the decoder environment to start decoding.
-- @tparam #string msg The message that needs to be decoded.
-- @treturn #string A string representing the tag is returned.
function Decoder:init_decode(msg)
  runtime.log:info("Intializing message decoder")
  self.message = msg
  self.index = 1
  self.msglength = #msg
  self.current_tag = decode_byte(self)
  return self.current_tag
end

local fhbhMap = {
  [1] = "Fronthaul",
  [2] = "Backhaul",
  [3] = "Fronthaul_Backhaul",
}

--- Decodes agent onboard message which contains length, mac, interface type, parent mac, sta count,
-- number of radios, radio id, radio type and BSSID.
-- @tparam #string msg The message that needs to be decoded.
-- @treturn #table A table containing decoded data.

function Decoder:AGENT_ONBOARD(msg)
  if self.current_tag == 2 then
    runtime.log:info("Decoding AGENT ONBOARD message")
  elseif self.current_tag == 4 then
    runtime.log:info("Decoding AGENT UPDATE message")
  end
  decode_number(self)
  local decodedData = {}
  decodedData.aleMac = decode_hex(self, 6)
  if self.current_tag == 4 then
    decodedData.msgType = decode_hex(self, 2)
  end
  decodedData.interfaceMac = runtime.agent_ipc_handler.formatMAC(decode_hex(self, 6))
  decodedData.interfaceType = decode_hex(self, 2)
  decodedData.manufacturerName = decode_string(self, decode_byte)
  decodedData.parentMAC = runtime.agent_ipc_handler.formatMAC(decode_hex(self, 6))
  decodedData.staCount = decode_byte(self)
  decodedData.numberOfRadios = tonumber(decode_byte(self)) or 0
  for index = 1, decodedData.numberOfRadios do
    local key = "radio_" .. index
    decodedData[key] = {}
    decodedData[key].radioID = runtime.agent_ipc_handler.formatMAC(decode_hex(self, 6))
    decodedData[key].radiotype = decode_byte(self)
    decodedData[key].BSSCount = tonumber(decode_byte(self)) or 0
    decodedData[key].BSSID = {}
    for BSSIndex = 1, decodedData[key].BSSCount do
      local bssid = runtime.agent_ipc_handler.formatMAC(decode_hex(self, 6))
      local bssType = decode_byte(self)
      if fhbhMap[bssType] then
        local bssMacs = decodedData[key].BSSID["BSSID_" .. fhbhMap[bssType]] or {}
        bssMacs[#bssMacs + 1] = bssid
        decodedData[key].BSSID["BSSID_" .. fhbhMap[bssType]] = bssMacs
      end
    end
  end
  return decodedData
end

--- Decodes agent offboard message which contains agent's MAC address.
-- @tparam #string msg The message that needs to be decoded.
-- @treturn #string A string respresenting MAC address is returned
function Decoder:AGENT_OFFBOARD(msg)
  runtime.log:info("Decoding OFFBOARD message")
  decode_number(self)
  return decode_hex(self, 6)
end

--- Decode the response message of get basic info request sent to agent.
-- @tparam #string msg The message that needs to be decoded.
-- @treturn #table A table containing decoded data.
function Decoder:DATA_1905_AVAILABLE(msg)
  runtime.log:info("Decoding 1905 DATA received")
  decode_number(self)
  local decodedData = {}
  decodedData.msgType = tonumber(decode_hex(self, 2)) or 0
  decodedData.TLVType = decode_byte(self)
  decodedData.aleMac = decode_hex(self, 6)
  decodedData.TLVLength = decode_number(self)
  if decodedData.msgType == 4 and decodedData.TLVType == 11 then
    decodedData.responseType = decode_number(self)
    runtime.log:info("TLV response type of 1905 message received: %d", decodedData.responseType)
    decodedData.vendorInfo = decode_string(self, decode_1905_length)
  end
  return decodedData
end

local operatingStandard = {
  [0] = "802.11b",
  [1] = "802.11g",
  [2] = "802.11a",
  [3] = "802.11n",
  [4] = "802.11ac",
  [5] = "802.11an",
  [6] = "802.11anac",
  [7] = "802.11ax"
}

--- Decodes station connect message which contains length, alemac, number of stations connected,
-- bssid, station mac and operating standard.
-- @tparam #string msg The message that needs to be decoded.
-- @treturn #table A table containing decoded data.
function Decoder:STA_CONNECT(msg)
  runtime.log:info("Decoding STATION CONNECT message")
  decode_number(self)
  local staConnectData = {}
  local aleMac = decode_hex(self, 6)
  staConnectData.aleMac = aleMac
  staConnectData[aleMac] = {}
  staConnectData[aleMac]["stations"] = {}
  staConnectData.numberOfStations = tonumber(decode_byte(self)) or 0
  for index = 1, staConnectData.numberOfStations do
    local staMac = runtime.agent_ipc_handler.formatMAC(decode_hex(self, 6))
    staConnectData[aleMac]["stations"][staMac] = {
      MACAddress = staMac,
      BSSID = runtime.agent_ipc_handler.formatMAC(decode_hex(self, 6)),
      OperatingStandard = operatingStandard[tonumber(decode_byte(self))],
      Active = "1"
    }
  end
  return staConnectData
end

--- Decodes station disconnect message which contains length, alemac, number of stations disconnected,
-- bssid and station mac.
-- @tparam #string msg The message that needs to be decoded.
-- @treturn #table A table containing decoded data.
function Decoder:STA_DISCONNECT(msg)
  runtime.log:info("Decoding STATION DISCONNECT message")
  decode_number(self)
  local aleMac = decode_hex(self, 6)
  local staDisconnectData = {}
  staDisconnectData.aleMac = aleMac
  staDisconnectData[aleMac] = {}
  staDisconnectData[aleMac]["stations"] = {}
  staDisconnectData.numberOfStations = tonumber(decode_byte(self)) or 0
  for index = 1, staDisconnectData.numberOfStations do
    local staMac = runtime.agent_ipc_handler.formatMAC(decode_hex(self, 6))
    staDisconnectData[aleMac]["stations"][staMac] = {
      MACAddress = staMac,
      BSSID = runtime.agent_ipc_handler.formatMAC(decode_hex(self, 6)),
      Active = "0"
    }
  end
  return staDisconnectData
end

--- Decodes station metrics message which contains length, station count, station mac, signal strength,
-- last datadownlinkrate, last datauplinkrate, bytes sent, bytes received, packets sent, Tx packets errors
-- and retransmissioncount.
-- @tparam #string msg The message that needs to be decoded.
-- @treturn #table A table containing decoded data.
function Decoder:STA_METRICS(msg)
  runtime.log:info("Decoding STATION METRICS message")
  decode_number(self)
  local stationMetrics = {}
  local numberOfStations = tonumber(decode_byte(self)) or 0
  for index = 1, numberOfStations do
    local stationMAC = decode_hex(self, 6)
    stationMetrics[stationMAC] = {
      MACAddress = runtime.agent_ipc_handler.formatMAC(stationMAC),
      SignalStrength = decode_byte(self),
      LastDataDownlinkRate = decode_1905_length(self),
      LastDataUplinkRate = decode_1905_length(self),
      BytesSent = decode_1905_length(self),
      BytesReceived = decode_1905_length(self),
      PacketsSent = decode_1905_length(self),
      PacketsReceived = decode_1905_length(self),
      ErrorsSent = decode_1905_length(self),
      RetransCount = decode_1905_length(self)
    }
  end
  return stationMetrics
end

--- Decodes the AP metrics message which contains length, agent count, ale mac, datalink rate, signal strenth.
-- @tparam #string msg The message that needs to be decoded.
-- @treturn  #table A table containing decoded data.
function Decoder:AP_METRICS(msg)
  runtime.log:info("Decoding the AP METRICS message")
  decode_number(self)
  local decodedData = {}
  local agentCount = tonumber(decode_byte(self)) or 0
  for index = 1, agentCount do
    local aleMac = runtime.agent_ipc_handler.formatMAC(decode_hex(self, 6))
    decodedData[aleMac] = {
      lastDataLinkRate = decode_number(self),
      signalStrength = decode_byte(self),
    }
  end
  return decodedData
end

--- Decodes multicast status message which contains length, uuid, multicast status,
-- if status is failure, then it will have agent count where Controller wasnt able to get the ACK responses
-- @tparam #string msg The message that needs to be decoded.
-- @treturn #table A table containing decoded data.
function Decoder:MULTICAST_STATUS(msg)
  runtime.log:info("Decoding MULTICAST STATUS message")
  decode_number(self)
  local uuid = decode_hex(self, 2) -- for uuid
  local status = decode_byte(self)
  local multicastStatus = { status = status, uuid = uuid }
  multicastStatus.agentsNotResponded = {}
  if status == "1" then
    local agentCount = decode_byte(self)
    for count = 1, agentCount do
      local agentMac = runtime.agent_ipc_handler.formatMAC(decode_hex(self, 6))
      multicastStatus.agentsNotResponded[agentMac] = true
    end
  end
  return multicastStatus
end

local M = {}

M.init = function(rt)
  runtime  = rt
end

M.new = function()
  local self = {
    -- The message we received.
    message = "",
    -- Pointer to where we are in the message.
    index = 1,
    -- The length of the message we received.
    msglength = 0,
    current_tag = nil,
  }
  return setmetatable(self, Decoder)
end

return M
