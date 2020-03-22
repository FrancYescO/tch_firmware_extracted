local M = {}

function M.entry(runtime)
    local uci = runtime.uci
    local conn = runtime.ubus

    if not uci or not conn then
        return false
    end
    return true
end

function M.exit(runtime, l2type)
    local uci = runtime.uci

    if not uci then
        return false
    end
    return true
end

return M
