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

    return true
end

function M.exit(runtime, l2type)
    return true
end

return M
