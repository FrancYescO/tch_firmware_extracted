--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local floor = math.floor
local char, sub, byte = string.char, string.sub, string.byte
local ipairs, setmetatable, tonumber = ipairs, setmetatable, tonumber

local Encoder = {}
Encoder.__index = Encoder

--- Helper function to encode a byte.
-- @param self A reference to a message encoder.
-- @param #number by A number between 0 and 255 that represents the byte.
local function encode_byte(self, by)
  local data = self.temp_data
  local data_len = self.temp_data_len
  data[#data + 1] = char(by)
  self.temp_data_len =  data_len + 1
end

--- Helper function to encode a two digit hexadecimal number.
-- @param #table self A reference to a message encoder.
-- @param #string hex A string representation of two hexadecimal digits.
local function encode_double_hex(self, hex)
  local by = tonumber(hex, 16)
  encode_byte(self, by)
end

--- Helper function to encode a number.
-- @param self A reference to a message encoder.
-- @param #number number The number to encode.
-- NOTE: The number to encode can not be larger than 65535.
local function encode_number(self, number)
  local data = self.temp_data
  local data_len = self.temp_data_len
  local hi = floor(number/256)
  local lo = number % 256
  data[#data+1] = char(hi, lo)
  self.temp_data_len = data_len + 2
end

--- Helper function to encode a string.
-- @param self A reference to a message encoder.
-- @param #string str The string to encode.
-- NOTE: The length of the given string can not exceed 65535. This limit is imposed by
--       the usage of the encode_number function.
local function encode_string(self, str)
  local s_len = #str
  encode_number(self, s_len)
  local data = self.temp_data
  local data_len = self.temp_data_len
  data[#data + 1] = str
  self.temp_data_len = data_len + s_len
end

--- Helper function to encode a UUID.
-- @param #table self A reference to a message encoder.
-- @param #string uuid The UUID to encode (without hyphens).
local function encode_uuid(self, uuid)
  local i = 1
  while i <= 32 do
    encode_double_hex(self, sub(uuid, i, i+1))
    i = i + 2
  end
end

local function confirm_encoding(self)
  local data_len = self.data_len
  local temp_len = self.temp_data_len
  if data_len + temp_len >= self.max_size then
    self.temp_data = {}
    self.temp_data_len = 0
    return false
  end
  local data = self.data
  local temp_data = self.temp_data
  for i=1,#temp_data do
    data[#data + 1] = temp_data[i]
  end
  self.data_len = data_len + temp_len
  self.temp_data = {}
  self.temp_data_len = 0
  return true
end

-----------------------
-- Response messages --
-----------------------

--- Encodes an ERROR message consisting of an error code and message.
-- @param #number errcode The error code to be encoded.
-- @param #string msg The error message to be encoded.
function Encoder:ERROR(errcode, msg)
  encode_number(self, errcode)
  encode_string(self, msg)
  return confirm_encoding(self)
end

--- Encodes a GPV_RESP message consisting of a path, name, value and type.
-- @param #string ppath The path to be encoded.
-- @param #string pname The parameter name to be encoded.
-- @param #string pvalue The parameter value to be encoded.
-- @param #string ptype The parameter type to be encoded.
function Encoder:GPV_RESP(ppath, pname, pvalue, ptype)
  encode_string(self, ppath)
  encode_string(self, pname)
  encode_string(self, pvalue)
  encode_string(self, ptype)
  return confirm_encoding(self)
end

--- Encodes a SPV_RESP message, which is either nothing or an error code,
-- error message and path
-- @param #number or #nil errcode Either an error code or nil if everything went fine.
-- @param #string errmsg If an error occurred this contains the error message.
-- @param #string path If an error occurred this contains the path that caused the error.
function Encoder:SPV_RESP(errcode, errmsg, path)
  if errcode then
    encode_number(self, errcode)
    encode_string(self, path)
    encode_string(self, errmsg)
  end
  return confirm_encoding(self)
end

--- Encodes a ADD_RESP message consisting of an instance reference.
-- @param #string instance The instance reference to be encoded.
function Encoder:ADD_RESP(instance)
  encode_string(self, instance)
  return confirm_encoding(self)
end

--- Encodes a DEL_RESP message which doesn't contain anything.
function Encoder:DEL_RESP()
  return true
end

--- Encodes a GPN_RESP message consisting of a path, name and 'writable'
-- boolean.
-- @param #string path The path to be encoded.
-- @param #string name The parameter name to be encoded.
-- @param #boolean writable The writable state to be encoded.
function Encoder:GPN_RESP(path, name, writable)
  encode_string(self, path)
  encode_string(self, name)
  encode_number(self, writable and 1 or 0)
  return confirm_encoding(self)
end

--- Encodes a RESOLVE_RESP message consisting of a path.
-- @param #string path The path to be encoded.
function Encoder:RESOLVE_RESP(path)
  encode_string(self, path)
  return confirm_encoding(self)
end

--- Encodes a SUBSCRIBE_RESP message consisting of a subscription ID and
-- a possible collection of paths.
-- @param #number id The subscription ID to be encoded.
-- @param #table paths The optional paths of non-evented parameters covered by
--                     the subscription.
function Encoder:SUBSCRIBE_RESP(id, paths)
  encode_number(self, id)
  if paths then
    for _, path in ipairs(paths) do
      encode_string(self, path)
    end
  end
  return confirm_encoding(self)
end

--- Encodes a UNSUBSCRIBE_RESP message which doesn't contain anything.
function Encoder:UNSUBSCRIBE_RESP()
  return true
end

--- Encodes an EVENT message consisting of a subscription ID, a path string,
-- event type and optional changed value.
-- @param #number subid The subscription ID to be encoded.
-- @param #string path The path that generated the event.
-- @param #number event_type The event type mask.
-- @param #string value The new value of the changed path in case of an update event.
function Encoder:EVENT(subid, path, event_type, value)
  encode_number(self, subid)
  encode_string(self, path)
  encode_byte(self, event_type)
  if value then
    encode_string(self, value)
  end
  return confirm_encoding(self)
end

--- Encodes a GPL_RESP message consisting of a path and name.
-- @param #string ppath The path to be encoded.
-- @param #string pname The parameter name to be encoded.
function Encoder:GPL_RESP(ppath, pname)
  encode_string(self, ppath)
  encode_string(self, pname)
  return confirm_encoding(self)
end

--- Encodes a GPC_RESP message consisting of the count of parameters.
-- @param #number ppcount The number of parameters.
function Encoder:GPC_RESP(pcount)
  encode_number(self, pcount)
  return confirm_encoding(self)
end

--- Encodes a GPV_NO_ABORT_RESP message consisting of a path, name, value and type.
-- @param #string ppath The path to be encoded.
-- @param #string pname The parameter name to be encoded.
-- @param #string pvalue The parameter value to be encoded.
-- @param #string ptype The parameter type to be encoded.
Encoder.GPV_NO_ABORT_RESP = Encoder.GPV_RESP

----------------------
-- Request messages --
----------------------

--- Encodes a GPV_REQ message consisting of a path.
-- @param #string path The path to be encoded.
function Encoder:GPV_REQ(path)
  encode_string(self, path)
  return confirm_encoding(self)
end

--- Encodes a SPV_REQ message consisting of a path and value.
-- @param #string path The path to be encoded.
-- @param #string value The value to be encoded.
function Encoder:SPV_REQ(path, value)
  encode_string(self, path)
  encode_string(self, value)
  return confirm_encoding(self)
end

--- Encodes a APPLY message consisting of nothing.
function Encoder:APPLY()
  return true
end

--- Encodes a ADD_REQ message consisting of a path and optional name.
-- @param #string path The path to be encoded.
-- @param #string name The optional name to be encoded.
function Encoder:ADD_REQ(path, name)
  encode_string(self, path)
  if name then
    encode_string(self, name)
  end
  return confirm_encoding(self)
end

--- Encodes a DEL_REQ message consisting of a path.
-- @param #string path The path to be encoded.
function Encoder:DEL_REQ(path)
  encode_string(self, path)
  return confirm_encoding(self)
end

--- Encodes a GPN_REQ message consisting of a path and a 'level' number.
-- @param #string path The path to be encoded.
-- @param #number level The level to be encoded.
function Encoder:GPN_REQ(path, level)
  encode_string(self, path)
  encode_number(self, level)
  return confirm_encoding(self)
end

--- Encodes a RESOLVE_REQ message consisting of a path and a key.
-- @param #string path The path to be encoded.
-- @param #string key The key to be encoded.
function Encoder:RESOLVE_REQ(path, key)
  encode_string(self, path)
  encode_string(self, key)
  return confirm_encoding(self)
end

--- Encodes a SUBSCRIBE_REQ message consisting of a path, socket address,
-- subscription type mask and options mask.
-- @param #string path The path to be encoded.
-- @param #string address The socket address to be encoded.
-- @param #number subscr_type The subscription type mask to be encoded.
-- @param #number options The options mask to be encoded.
function Encoder:SUBSCRIBE_REQ(path, address, subscr_type, options)
  encode_string(self, path)
  encode_string(self, address)
  encode_byte(self, subscr_type)
  encode_byte(self, options)
  return confirm_encoding(self)
end

--- Encodes an UNSUBSCRIBE_REQ message consisting of a subscription id.
-- @param #string id The subscription id to be unsubscribed.
function Encoder:UNSUBSCRIBE_REQ(id)
  encode_number(self, id)
  return confirm_encoding(self)
end

--- Encodes a GPL_REQ message consisting of a path.
-- @param #string path The path to be encoded.
function Encoder:GPL_REQ(path)
  encode_string(self, path)
  return confirm_encoding(self)
end

--- Encodes a GPC_REQ message consisting of a path.
-- @param #string path The path to be encoded.
function Encoder:GPC_REQ(path)
  encode_string(self, path)
  return confirm_encoding(self)
end

--- Encodes a GPV_NO_ABORT_REQ message consisting of a path.
-- @param #string path The path to be encoded.
Encoder.GPV_NO_ABORT_REQ = Encoder.GPV_REQ

---
-- Initialize the encoder environment to encode messages of the given tag.
-- @param #string tag The tag of the message we wish to encode.
-- @param #number max_size The maximum size of a single message.
-- @param #string uuid (optional) If we are encoding a request, we need to supply
--                     it with a UUID.
-- NOTE: This function MUST be called before encode() or mark_last()
-- can be used.
function Encoder:init_encode(tag, max_size, uuid)
  self.data = {}
  self.data_len = 0
  self.max_size = max_size
  self.temp_data = {}
  self.temp_data_len = 0
  encode_byte(self, tag)
  if uuid then
    encode_uuid(self, uuid)
  end
  return confirm_encoding(self)
end

---
-- Marks the data in 'data' as being the last of a set.
function Encoder:mark_last()
  local tag = byte(self.data[1])
  if tag < 128 then
    self.data[1] = char(tag + 128)
  end
end

function Encoder:retrieve_data()
  return self.data
end

local M = {}

M.new = function()
  local self = {
    -- An array to which the encodings should be added.
    data = {},
    -- The total length of the data currently in the 'data' table.
    data_len = 0,
    -- The maximum allowed length for the data.
    max_size = 0,
    -- A temporary array that contains data we wish to add to the encoding.
    temp_data = {},
    -- The length of the new data.
    temp_data_len = 0,
  }
  return setmetatable(self, Encoder)
end

return M
