--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local setmetatable, require = setmetatable, require
local byte, sub = string.byte, string.sub

local Decoder = {}
Decoder.__index = Decoder

local function isRequest(self, tag)
  if tag == self.tags["GPV_REQ"] or tag == self.tags["SPV_REQ"] or tag == self.tags["APPLY"] or tag == self.tags["ADD_REQ"]
     or tag == self.tags["DEL_REQ"] or tag == self.tags["GPN_REQ"] or tag == self.tags["RESOLVE_REQ"] or tag == self.tags["SUBSCRIBE_REQ"]
     or tag == self.tags["UNSUBSCRIBE_REQ"] or tag == self.tags["GPL_REQ"] or tag == self.tags["GPC_REQ"] or tag == self.tags["GPV_NO_ABORT_REQ"] then
    return true
  end
  return false
end

--- Helper function to decode a byte.
-- @param self A reference to a message decoder.
-- @return #number A number between 0 and 255 that represents the decoded byte.
local function decode_byte(self)
  local message = self.message
  local index = self.index
  local by = byte(message, index)
  self.index = index + 1
  return by
end

local hexpattern = "%02X"

--- Helper function to decode a two digit hexadecimal number.
-- @param #table self A reference to a message decoder.
-- @return #string A string representation of two hexadecimal digits.
local function decode_double_hex(self)
  local by = decode_byte(self)
  return hexpattern:format(by)
end

--- Helper function to decode a number.
-- @param self A reference to a message decoder.
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

--- Helper function to decode a string.
-- @param self A reference to a message decoder.
-- @return #string The decoded string.
local function decode_string(self)
  local length = decode_number(self)
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

--- Helper function to decode a UUID
-- @param #table self A reference to a message decoder.
-- @return #string The decoded UUID (without hyphens).
local function decode_uuid(self)
  local uuid = ""
  local i = 1
  while i <= 16 do
    uuid = uuid..decode_double_hex(self)
    i = i + 1
  end
  return uuid
end

-----------------------
-- Response messages --
-----------------------

--- Decodes an ERROR message consisting of an error code and message.
-- @return #table A table with 'errcode' and 'errmsg' fields.
function Decoder:ERROR()
  local errcode = decode_number(self)
  local errmsg = decode_string(self)
  return { errcode = errcode, errmsg = errmsg }
end

--- Decodes a GPV_RESP message consisting of a path, name, value and type.
-- @return #table An array of tables with 'path', 'param', 'value' and 'type' fields.
function Decoder:GPV_RESP()
  local data = {}
  while (self.index < self.msglength) do
    local path, param, value, type
    path = decode_string(self)
    param = decode_string(self)
    value = decode_string(self)
    type = decode_string(self)
    data[#data + 1] = { path = path, param = param, value = value, type = type }
  end
  return data
end

--- Decodes a SPV_RESP message which might be nothing or a list of errors.
-- @return #table An empty table if everything went alright, otherwise an array of tables
--                with 'errcode', 'errmsg' and 'path' fields.
function Decoder:SPV_RESP()
  local response = {}
  while (self.index < self.msglength) do
    local code, errmsg, path
    code = decode_number(self)
    path = decode_string(self)
    errmsg = decode_string(self)
    response[#response+1] = {errcode=code, errmsg=errmsg, path=path}
  end
  return response
end

--- Decodes a ADD_RESP message consisting of an instance reference.
-- @return #string The decoded instance reference.
function Decoder:ADD_RESP()
  return decode_string(self)
end

--- Decodes a DEL_RESP message which doesn't contain anything.
function Decoder:DEL_RESP()

end

--- Decodes a GPN_RESP message consisting of a path, name and 'writable'
-- boolean.
-- @return #table An array of tables with 'path' (string), 'name' (string) and
--                'writable' (boolean) fields.
function Decoder:GPN_RESP()
  local data = {}
  while (self.index < self.msglength) do
    local path, name, writable
    path = decode_string(self)
    name = decode_string(self)
    writable = decode_number(self)
    writable = not (writable == 0)
    data[#data + 1] = { path = path, name = name, writable = writable }
  end
  return data
end

--- Decodes a RESOLVE_RESP message consisting of a path.
-- @return #string The decoded instance path.
function Decoder:RESOLVE_RESP()
  return decode_string(self)
end

--- Decodes a SUBSCRIBE_RESP message consisting of a subscription ID and
-- a possible collection of paths.
-- @return #table A table with 'id' and 'nonevented' (array) fields.
function Decoder:SUBSCRIBE_RESP()
  local id, nonevented
  id = decode_number(self)
  nonevented = {}
  while (self.index < self.msglength) do
    nonevented[#nonevented+1] = decode_string(self)
  end
  return { id = id, nonevented = nonevented }
end

--- Decodes a UNSUBSCRIBE_RESP message which doesn't contain anything.
function Decoder:UNSUBSCRIBE_RESP()

end

--- Decodes an EVENT message consisting of a subscription ID, a path that generated
-- the event, the type of event and optionally a new value for the update event.
-- @return #table A table with 'id', 'path', 'eventmask' and 'value' fields.
function Decoder:EVENT()
  local subid, path, event_type, value
  subid = decode_number(self)
  path = decode_string(self)
  event_type = decode_byte(self)
  if (self.index < self.msglength) then
    value = decode_string(self)
  end
  return { id = subid, path = path, eventmask = event_type, value = value}
end

--- Decodes a GPL_RESP message consisting of a path and name.
-- @return #table An array of tables with 'path' and 'param' fields.
function Decoder:GPL_RESP()
  local data = {}
  while (self.index < self.msglength) do
    local path, param
    path = decode_string(self)
    param = decode_string(self)
    data[#data + 1] = { path = path, param = param }
  end
  return data
end

--- Decodes a GPC_RESP message consisting of a number.
-- @return #number The decoded number of parameters.
function Decoder:GPC_RESP()
  return decode_number(self)
end

--- Decodes a GPV_NO_ABORT_RESP message consisting of a path, name, value and type.
-- @return #table An array of tables with 'path', 'param', 'value' and 'type' fields.
Decoder.GPV_NO_ABORT_RESP = Decoder.GPV_RESP

----------------------
-- Request messages --
----------------------

--- Decodes a GPV_REQ message consisting of one or more paths.
-- @return #table An array of paths.
function Decoder:GPV_REQ()
  local data = {}
  while (self.index < self.msglength) do
    data[#data + 1] = decode_string(self)
  end
  return data
end

--- Decodes a SPV_REQ message consisting or one or more path,value combinations.
-- @return #table An array of tables with 'path' and 'value' fields.
function Decoder:SPV_REQ()
  local request = {}
  while (self.index < self.msglength) do
    local path, value
    path = decode_string(self)
    value = decode_string(self)
    request[#request+1] = {path=path, value=value}
  end
  return request
end

--- Decodes a APPLY message consisting of nothing.
function Decoder:APPLY()

end

--- Decodes a ADD_REQ message consisting of a path and an optional name.
-- @return #table A table with 'path' and 'name' fields. The 'name' field may be
--                empty.
function Decoder:ADD_REQ()
  local path, name
  path = decode_string(self)
  if self.index < self.msglength then
    name = decode_string(self)
  end
  return { path = path, name = name }
end

--- Decodes a DEL_REQ message consisting of a path.
-- @return #string The decoded path.
function Decoder:DEL_REQ()
  return decode_string(self)
end

--- Decodes a GPN_REQ message consisting of a path and a 'level' number.
-- @return #table A table with 'path' and 'level' fields.
function Decoder:GPN_REQ()
  local path, level
  path = decode_string(self)
  level = decode_number(self)
  return { path = path, level = level }
end

--- Decodes a RESOLVE_REQ message consisting of a path and a key.
-- @return #table A table with 'path' and 'key' fields.
function Decoder:RESOLVE_REQ()
  local path, key
  path = decode_string(self)
  key = decode_string(self)
  return { path = path, key = key }
end

--- Decodes a SUBSCRIBE_REQ message consisting of a path, socket address,
-- subscription type mask and options mask.
-- @return #table A table with 'path', 'address', 'subscription' and 'options' fields.
function Decoder:SUBSCRIBE_REQ()
  local path, domainsock, subscr, options
  path = decode_string(self)
  domainsock = decode_string(self)
  subscr = decode_byte(self)
  options = decode_byte(self)
  return { path = path, address = domainsock, subscription = subscr, options = options }
end

--- Decodes a UNSUBSCRIBE_REQ message consisting of a subscription id.
-- @return #string The subscription id.
function Decoder:UNSUBSCRIBE_REQ()
  return decode_number(self)
end

--- Decodes a GPL_REQ message consisting of one or more paths.
-- @return #table An array of paths.
function Decoder:GPL_REQ()
  local data = {}
  while (self.index < self.msglength) do
    data[#data + 1] = decode_string(self)
  end
  return data
end

--- Decodes a GPC_REQ message consisting of one or more paths.
-- @return #table An array of paths.
function Decoder:GPC_REQ()
  local data = {}
  while (self.index < self.msglength) do
    data[#data + 1] = decode_string(self)
  end
  return data
end

--- Decodes a GPV_NO_ABORT_REQ message consisting of one or more paths.
-- @return #table An array of paths.
Decoder.GPV_NO_ABORT_REQ = Decoder.GPV_REQ

--- Initialize the decoder environment to start decoding.
-- @param #string msg The message that needs to be decoded.
-- @return #string, #boolean, #string
--         A string representing the tag is returned together with a boolean
--         which indicates if this is the final message or not. The final return
--         value will contain the UUID if the given message is a request message.
function Decoder:init_decode(msg)
  self.message = msg
  self.index = 1
  self.msglength = #msg
  local tag = decode_byte(self)
  local is_last = false
  if tag > 127 then
    is_last = true
    tag = tag - 128
  end
  local uuid
  if isRequest(self, tag) then
    uuid = decode_uuid(self)
  end
  return tag, is_last, uuid
end

local M = {}

M.new = function(tags)
  local self = {
    -- The message we received.
    message = "",
    -- Pointer to where we are in the message.
    index = 1,
    -- The length of the message we received.
    msglength = 0,
    tags = tags,
  }
  return setmetatable(self, Decoder)
end

return M
