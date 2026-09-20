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
local conn
local event_conn
do
  local ubus = require("ubus")
  conn = ubus.connect()
  event_conn = ubus.connect()
  if not conn or not event_conn then
    error("Failed to connect to ubusd")
  end
  local __index = getmetatable(conn).__index
  __index.close = function()
    -- just ignore a close request
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
