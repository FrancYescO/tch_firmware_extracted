--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local require, setmetatable = require, setmetatable

local msg_encode = require("transformer.msg_encode")
local msg_decode = require("transformer.msg_decode")

-- The supported tag values. There can never be more than 127 different tags.
local ERROR    = 1
local GPV_REQ  = 2
local GPV_RESP = 3
local SPV_REQ  = 4
local SPV_RESP = 5
local APPLY    = 6
local ADD_REQ  = 7
local ADD_RESP = 8
local DEL_REQ  = 9
local DEL_RESP = 10
local GPN_REQ  = 11
local GPN_RESP = 12
local RESOLVE_REQ  = 13
local RESOLVE_RESP = 14
local SUBSCRIBE_REQ = 15
local SUBSCRIBE_RESP = 16
local UNSUBSCRIBE_REQ = 17
local UNSUBSCRIBE_RESP = 18
local EVENT = 19
local GPL_REQ = 20
local GPL_RESP = 21
local GPC_REQ = 22
local GPC_RESP = 23
local GPV_NO_ABORT_REQ = 24
local GPV_NO_ABORT_RESP = 25


-------------------------------------------------------------
-- Module that can serialize and deserialize data so you
-- can invoke Transformer from a different process.
--
-- Messages start with a tag byte indicating which type of
-- message it is. If the highest bit is set this means that
-- the data in the message is the last of a series. If the message
-- is a request, the 16 bytes after the tag byte should contain
-- the identification of the sender.
-- 
-- What follows the tag byte is dependent on the tag.
-- Numbers (error codes) are typically encoded as two bytes
-- in big endian order. Strings are encoded as the length
-- of the string as two bytes in big endian order,
-- followed by the actual string data. This data is NOT
-- necessarily zero terminated.
-------------------------------------------------------------
local Msg = {}
Msg.__index = Msg

--- Enum of the supported tags.
Msg.tags = {
  --- Error message consists of (excluding tag byte):
  -- * 2 bytes (big endian) for error code
  -- * 2 bytes (big endian) for length of following string
  -- * string with error message
  -- To encode such a message you provide an error code and
  -- an error message string.
  -- Decoding such a message returns a table with an 'errcode'
  -- and an 'errmsg' field.
  ERROR    = ERROR,
  --- GPV request message consists of (excluding tag byte and
  -- identification bytes) one or more sets of the following:
  -- * 2 bytes (big endian) for length of following string
  -- * string representing path to retrieve
  -- To encode such a message you provide one path in each
  -- call to msg.encode().
  -- Decoding such a message returns an array of the paths.
  GPV_REQ  = GPV_REQ,
  --- GPV response message consists of (excluding tag byte)
  -- one or more sets of the following:
  -- * 2 bytes (big endian) for length of following string
  -- * string representing the path to the object
  -- * 2 bytes length
  -- * string representing the parameter name
  -- * 2 bytes length
  -- * string representing the parameter value
  -- * 2 bytes length
  -- * string representing the type
  -- To encode such a message you provide a path string, a
  -- value string and a type string in each call to
  -- msg.encode().
  -- Decoding such a message returns an array of tables
  -- with 'path', 'param', 'value' and 'type' fields.
  GPV_RESP = GPV_RESP,
  --- SPV request message consists of (excluding tag byte
  -- and identification bytes) one or more sets of the following:
  -- * 2 bytes (big endian) for length of following string
  -- * string representing the path
  -- * 2 bytes length
  -- * 2 bytes representing the value
  -- To encode such a message you provide a path string and
  -- a value string in each call to msg.encode().
  -- Decoding such a message returns an array of tables
  -- with 'path' and 'value' fields.
  SPV_REQ  = SPV_REQ,
  --- SPV response message consists of (excluding tag byte)
  -- zero or more error responses:
  -- * 2 bytes (big endian) error code
  -- * 2 bytes length of following string
  -- * string representing the path
  -- * 2 bytes length
  -- * string representing an error message
  -- To encode such a message you either provide no values
  -- or an error code, an error message and a path in each
  -- call to msg.encode().
  -- Decoding such a message returns an array of tables with
  -- 'errcode', 'errmsg' and 'path' fields. An empty array
  -- means all sets succeeded.
  SPV_RESP = SPV_RESP,
  --- Apply messages only consist of the tag byte and identification
  -- bytes and no additional data.
  APPLY = APPLY,
  --- AddObject request message consists of (excluding tag byte and
  -- identification bytes):
  -- * 2 bytes (big endian) for length of following string
  -- * string representing the path to add to
  -- * (optional) 2 bytes (big endian) for length of following string
  -- * (optional) string representing the name to be used for created instance
  -- * instance name is optional and only applicable for named MI
  -- To encode such a message you provide one path string
  -- in a call to msg.encode().
  -- Decoding such a message returns a path.
  ADD_REQ  = ADD_REQ,
  --- AddObject response message consists of (excluding tag byte):
  -- * 2 bytes (big endian) for length of following string
  -- * string representing the created instance number/key
  -- To encode such a message you provide an
  -- instance number in a call to
  -- msg.encode().
  -- Decoding such a message returns an instance number.
  ADD_RESP = ADD_RESP,
  --- DeleteObject request message consists of (excluding tag byte
  -- and identification bytes):
  -- * 2 bytes (big endian) for length of following string
  -- * string representing the path to delete
  -- To encode such a message you provide one path string
  -- in a call to msg.encode().
  -- Decoding such a message returns a path.
  DEL_REQ  = DEL_REQ,
  --- DeleteObject response messages only consist of the tag byte and no data.
  DEL_RESP = DEL_RESP,
  --- GetParameterNames request message consists of (excluding tag byte
  -- and identification bytes):
  -- * 2 bytes (big endian) for length of following string
  -- * string representing the path
  -- * 2 bytes (big endian) for the number 'level' (we could do it
  --   in one byte but this makes it easier to share code)
  -- To encode such a message you provide one path string and one number
  -- in each call to msg.encode().
  -- Decoding such a message returns a table with a `path` field (a string)
  -- and a `level` field (a number).
  GPN_REQ = GPN_REQ,
  --- GetParameterNames response message consists of (excluding tag byte)
  -- one or more sets of the following:
  -- * 2 bytes (big endian) for length of following string
  -- * string representing the path to the object
  -- * 2 bytes length
  -- * string representing the parameter name (can be empty)
  -- * 2 bytes representing the 'writable' boolean (we could do it
  --   in one byte but this makes it easier to share code)
  -- To encode such a message you provide a path string, a parameter name
  -- (possibly an empty string but not nil!) and a boolean in each
  -- call to msg.encode().
  -- Decoding such a message returns an array of tables
  -- with 'path' (string), 'name' (string) and 'writable' (boolean) fields.
  GPN_RESP = GPN_RESP,
  --- Resolve request messages consist of (excluding tag byte and
  -- identifiation bytes):
  -- * 2 bytes (big endian) for the length of following string
  -- * string representing the path
  -- * 2 bytes for the length of following string
  -- * string representing the key
  -- To encode such a message you provide a path string, and a key
  -- string in a call to msg.encode().
  -- Decoding such a message returns a table with 'path' field and a
  -- 'key' field.
  RESOLVE_REQ = RESOLVE_REQ,
  --- Resolve response messages consist of (excluding tag byte):
  -- * 2 bytes (big endian) for the length of following string
  -- * string representing the path (can be empty)
  -- To encode such a message you provide a path string
  -- in a call to msg.encode().
  -- Decoding such a message returns an instance path.
  RESOLVE_RESP = RESOLVE_RESP,
  --- Subscribe request messages consist of (excluding tag byte and
  -- identification bytes):
  -- * 2 bytes (big endian) for the length of following string.
  -- * string representing the path to subscribe to.
  -- * 2 bytes (big endian) for the length of following string.
  -- * string representing the abstract Unix domain socket address.
  -- * 1 byte for the subscription type (bitwise OR of ADD, DEL and UPDATE).
  -- * 1 byte to pass more options (no_own_events, active, current_instances_only)
  SUBSCRIBE_REQ = SUBSCRIBE_REQ,
  --- Subscribe response messages consist of (excluding tag byte):
  -- * 2 bytes (big endian) for the subscription ID number
  --  (This imposes a hard-limit on the number of subscriptions per user)
  -- * Zero or more sets of the following:
  --   ** 2 bytes (big endian) for length of following string
  --   ** string representing the path of a non-evented parameter.
  SUBSCRIBE_RESP = SUBSCRIBE_RESP,
  --- Unsubscribe request messages consist of (excluding tag byte and
  -- identification bytes):
  -- * 2 bytes (big endian) for the subscription ID number
  UNSUBSCRIBE_REQ = UNSUBSCRIBE_REQ,
  --- Unsubscribe response messages only consist of the tag byte and no data.
  UNSUBSCRIBE_RESP = UNSUBSCRIBE_RESP,
  --- Event messages consist of (excluding tag byte):
  -- * 2 bytes (big endian) for the subscription ID number.
  -- * 2 bytes (big endian) for the length of following string.
  -- * string representing the path that caused the event.
  -- * 1 byte for the event type (bitwise or of ADD, DEL and UPDATE).
  -- * (optional) 2 bytes for the length of following string.
  -- * (optional) string representing the new changed value.
  EVENT = EVENT,
  --- GPL request message consists of (excluding tag byte and
  -- identification bytes) one or more sets of the following:
  -- * 2 bytes (big endian) for length of following string
  -- * string representing path to retrieve
  -- To encode such a message you provide one path in each
  -- call to msg.encode().
  -- Decoding such a message returns an array of the paths.
  GPL_REQ = GPL_REQ,
  --- GPL response message consists of (excluding tag byte)
  -- one or more sets of the following:
  -- * 2 bytes (big endian) for length of following string
  -- * string representing the path to the object
  -- * 2 bytes length
  -- * string representing the parameter name
  -- To encode such a message you provide a path and
  -- a parameter name string in each call to msg.encode().
  -- Decoding such a message returns an array of tables
  -- with 'path' and 'param' fields.
  GPL_RESP = GPL_RESP,
  --- GetParameterCount request message consists of (excluding tag byte
  -- and identification bytes) one or more sets of the following:
  -- * 2 bytes (big endian) for length of following string
  -- * string representing the path
  -- To encode such a message you provide one path string
  -- in each call to msg.encode()..
  -- Decoding such a message returns an array of the paths.
  GPC_REQ = GPC_REQ,
  --- GetParameterCount response message consists of (excluding tag byte)
  -- * 2 bytes (big endian) for the number of parameters
  -- To encode such a message you provide a number in a
  -- call to msg.encode().
  -- Decoding such a message returns a number.
  GPC_RESP = GPC_RESP,
  --- GPV No Abort request message consists of (excluding tag byte and
  -- identification bytes) one or more sets of the following:
  -- * 2 bytes (big endian) for length of following string
  -- * string representing path to retrieve
  -- To encode such a message you provide one path in each
  -- call to msg.encode().
  -- Decoding such a message returns an array of the paths.
  GPV_NO_ABORT_REQ = GPV_NO_ABORT_REQ,
  --- GPV No Abort response message consists of (excluding tag byte)
  -- one or more sets of the following:
  -- * 2 bytes (big endian) for length of following string
  -- * string representing the path to the object
  -- * 2 bytes length
  -- * string representing the parameter name
  -- * 2 bytes length
  -- * string representing the parameter value. If the type is 'error', this will contain the error message.
  -- * 2 bytes length
  -- * string representing the type. If an error occurred, the type will be 'error'.
  -- To encode such a message you provide a path string, a
  -- value string and a type string in each call to
  -- msg.encode().
  -- Decoding such a message returns an array of tables
  -- with 'path', 'param', 'value' and 'type' fields.
  GPV_NO_ABORT_RESP = GPV_NO_ABORT_RESP,
}

Msg.header_length = 1
Msg.header_with_uuid_length = 17

------------------
-- Encode
------------------

function Msg:init_encode(tag, max_size, uuid)
  self.current_tag = tag
  return self.msg_encoder:init_encode(tag, max_size, uuid)
end

---
-- Encodes the given values in the given table as a
-- message of the given tag.
-- If there's already data present in 'data' then it
-- will be added at the end.
-- The message is NOT flagged as being the last; see
-- the mark_last() function.
-- Returns the number of bytes added to 'data'. When
-- an invalid tag is given 0 will be returned and the
-- state of 'data' is undefined.
-- NOTE: This will only work correctly if init_encode was
--       called first.
function Msg:encode(...)
  if self.encoders[self.current_tag] then
    return self.encoders[self.current_tag](self.msg_encoder, ...)
  end
  return false
end

function Msg:retrieve_data()
  return self.msg_encoder:retrieve_data()
end

function Msg:mark_last()
  self.msg_encoder:mark_last()
end

------------------
-- Decode
------------------

function Msg:init_decode(msg)
  local tag, is_last, uuid = self.msg_decoder:init_decode(msg)
  self.current_tag = tag
  return tag, is_last, uuid
end

---
-- Decode the given message.
-- Returns:
-- * the tag of the message
-- * a boolean indicating whether it's the last message
-- * a table with the decoded data; see the documentation
--   of msg.tags for details
-- In case of messages with an unknown tag the second and
-- third return value is undefined.
-- NOTE: This will only work correctly if init_decode was
--       called first.
function Msg:decode()
  if self.decoders[self.current_tag] then
    return self.decoders[self.current_tag](self.msg_decoder)
  end
end

local function load_functions(coder)
  local result = {}
  result[ERROR] = coder.ERROR
  result[GPV_REQ] = coder.GPV_REQ
  result[GPV_RESP] = coder.GPV_RESP
  result[SPV_REQ] = coder.SPV_REQ
  result[SPV_RESP] = coder.SPV_RESP
  result[APPLY] = coder.APPLY
  result[ADD_REQ] = coder.ADD_REQ
  result[ADD_RESP] = coder.ADD_RESP
  result[DEL_REQ] = coder.DEL_REQ
  result[DEL_RESP] = coder.DEL_RESP
  result[GPN_REQ] = coder.GPN_REQ
  result[GPN_RESP] = coder.GPN_RESP
  result[RESOLVE_REQ] = coder.RESOLVE_REQ
  result[RESOLVE_RESP] = coder.RESOLVE_RESP
  result[SUBSCRIBE_REQ] = coder.SUBSCRIBE_REQ
  result[SUBSCRIBE_RESP] = coder.SUBSCRIBE_RESP
  result[UNSUBSCRIBE_REQ] = coder.UNSUBSCRIBE_REQ
  result[UNSUBSCRIBE_RESP] = coder.UNSUBSCRIBE_RESP
  result[EVENT] = coder.EVENT
  result[GPL_REQ] = coder.GPL_REQ
  result[GPL_RESP] = coder.GPL_RESP
  result[GPC_REQ] = coder.GPC_REQ
  result[GPC_RESP] = coder.GPC_RESP
  result[GPV_NO_ABORT_REQ] = coder.GPV_NO_ABORT_REQ
  result[GPV_NO_ABORT_RESP] = coder.GPV_NO_ABORT_RESP
  return result
end

local M = {}

M.new = function()
  local encoder = msg_encode.new()
  local decoder = msg_decode.new(Msg.tags)
  local self = {
    msg_encoder = encoder,
    msg_decoder = decoder,
    current_tag = nil,
    encoders = load_functions(encoder),
    decoders = load_functions(decoder),
  }
  return setmetatable(self,Msg)
end

return M
