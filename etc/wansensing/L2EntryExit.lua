local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')

function M.entry(runtime)
    local uci = runtime.uci
    if not uci then
        return false
    end

    runtime.sfp_check_counter = 0
    runtime.ltebackup_delay_counter = 0
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
