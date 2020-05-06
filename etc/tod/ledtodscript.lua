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

function M.stop(runtime, actionname, object)
    local logger = runtime.logger
    local cursor = runtime.uci.cursor()
    local conn = runtime.ubus
    local packet = {}

    packet["state"] = "active"
    conn:send("ambient.status", packet)

    cursor:set(config, "ambient", "active", '1')
    cursor:commit(config)

    logger:notice(actionname .. ": turn on ambient led")
    return true
end

return M
