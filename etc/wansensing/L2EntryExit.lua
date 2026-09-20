local M = {}

function M.entry(runtime)
    local uci = runtime.uci
    local conn = runtime.ubus

    if not uci or not conn then
        return false
    end

    local x = uci.cursor()

    local currentstate = x:get("xdsl", "dsl0", "enabled")
    if currentstate ~= "1" then
        x:set("xdsl", "dsl0", "enabled", "1")
        x:commit("xdsl")
        os.execute("/etc/init.d/xdsl reload")
    end

    -- initialize ltebackup_delay_counter
    runtime.ltebackup_delay_counter = 0

    return true
end

function M.exit(runtime, l2type)
    local uci = runtime.uci

    if not uci then
        return false
    end

    -- restore factory defaults
    local x = uci.cursor()

    return true
end

return M
