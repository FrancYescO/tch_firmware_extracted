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

local function isCurTimeInSlot(cursor, logger)
    local h1, m1 = string.match(cursor:get("tod", "sleep_hours", "start_time"), "(%d+):(%d+)")
    local h2, m2 = string.match(cursor:get("tod", "sleep_hours", "stop_time"), "(%d+):(%d+)")
    local startTime = h1 * 3600 + m1 * 60
    local stopTime = h2 * 3600 + m2 * 60
    local h3, m3, s3 = string.match(os.date("%H:%M:%S"), "(%d+):(%d+):(%d+)")
    local curTime = h3 * 3600 + m3 * 60 + s3

    if (stopTime < startTime) then
        if (curTime < stopTime) then
            curTime = curTime + 24 * 3600;
        end
        stopTime = stopTime + 24 * 3600;
    end
    if (curTime > startTime and curTime < stopTime) then
	logger:notice("In time slot, Do not turn on ambient led")
        return 1
    else
	logger:notice("Not in time slot, turn on ambient led")
        return 0
    end
end

function M.stop(runtime, actionname, object)
    local logger = runtime.logger
    local cursor = runtime.uci.cursor()
    local conn = runtime.ubus
    local packet = {}
    local ret = isCurTimeInSlot(cursor, logger)
    if ret == 0 then
      packet["state"] = "active"
      conn:send("ambient.status", packet)

      cursor:set(config, "ambient", "active", '1')
      cursor:commit(config)

      logger:notice(actionname .. ": turn on ambient led")
    end
    return true
end

return M
