--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

--- The UBUS connection for mappings
-- @module transformer.mapper.ubus
--
-- Mappings are not allowed (by convention) to create their own UBUS connection.
-- They should use this helper to get a shared connection.
--
-- So mappings must never require ubus directly.
--
-- The typical use in a mapping file is:
-- local conn = mapper("ubus").connect()
--
-- and then later
-- conn:call(...)

-- Setup a single ubus connection to share with all mappings.
-- Make sure no-one can close the shared connection.
-- For event sending we need to use a different connection.
-- Otherwise somebody listening for that event on the same
-- connection will not receive it (!!).
local logger = require("tch.logger")
local conn
local event_conn
do
  local ubus = require("ubus")
  -- Override the default UBUS call timeout of 30 seconds to 2 seconds.
  -- If a UBUS call happens to a daemon while it is being started or stopped,
  -- this call can hang causing all other Transformer calls to hang as well.
  conn = ubus.connect(nil, 2)
  event_conn = ubus.connect()
  if not conn or not event_conn then
    error("Failed to connect to ubusd")
  end
  local __index = getmetatable(conn).__index
  __index.close = function()
    -- just ignore a close request
  end
  -- override the call() method to be able to log a message when
  -- a timeout happens
  local call = __index.call
  __index.call = function(_, path, method, ...)
    local ret, rv = call(conn, path, method, ...)
    -- Check ubusmsg.h for the possible return code values
    if not ret and tonumber(rv) == 7 then
      logger:warning("ubus call timeout on calling %s %s. %s", path, method, debug.traceback())
    end
    return ret, rv
  end
  -- override the send() method to
  -- use the dedicated event connection
  local send = __index.send
  __index.send = function(_, ...)
    send(event_conn, ...)
  end
end

local M = {}

--- Function to connect to UBUS
-- @returns a ubus connection object.
function M.connect()
  return conn
end

return M
