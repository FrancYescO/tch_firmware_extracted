local type = type
local match = string.match
local date = os.date
local M = {}
local config = "ledfw"

-- runtime is a lua table contains {ubus = conn, uci = uci, uloop = uloop, logger = logger}

function M.start(runtime, actionname, object)
  local logger = runtime.logger
  local cursor = runtime.uci.cursor()
  local conn = runtime.ubus
  local packet = {}

  packet["state"] = "inactive"
  conn:send("ambient.status", packet)

  cursor:set(config, "ambient", "active", '0')
  cursor:commit(config)

  logger:notice(actionname .. ": turn off ambient led")
  return true
end

local function CheckTimeSlot(cursor, logger)
  local h1, m1 = match(cursor:get("tod", "led_timer", "start_time"), "(%d+):(%d+)")
  local h2, m2 = match(cursor:get("tod", "led_timer", "stop_time"), "(%d+):(%d+)")
  local ch, cm = match(date("%H:%M"), "(%d+):(%d+)")
  local t1 = h1*60 + m1
  local t2 = h2*60 + m2
  local ct = ch*60 + cm
  if (t1 < t2 and t1 <= ct and ct < t2)
    or (t1 > t2 and (t1 <= ct or ct < t2)) then
    logger:notice("In time slot, Do not turn on ambient led")
    return true
  else
    logger:notice("Not in time slot, turn on ambient led")
    return false
  end
end

function M.stop(runtime, actionname, object)
  local logger = runtime.logger
  local cursor = runtime.uci.cursor()
  local conn = runtime.ubus
  local packet = {}
  if not CheckTimeSlot(cursor, logger) then
    packet["state"] = "active"
    conn:send("ambient.status", packet)

    cursor:set(config, "ambient", "active", '1')
    cursor:commit(config)

    logger:notice(actionname .. ": turn on ambient led")
  end
  return true
end

return M
