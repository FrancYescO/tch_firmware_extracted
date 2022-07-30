local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')
-- INPUT: 'runtime' is a lua table contains {ubus = conn, uci = uci, uloop = uloop, logger = logger};
-- INPUT: 'actionname' is the name of UCI 'action' section;

function M.start(runtime, actionname, object)
    local uci = runtime.uci
    local cursor = uci.cursor()
    local activated = cursor:get("tod","mobiled_backup","enabled")
    local network_mode = cursor:get("wansensing","global","network_mode")
    if activated == "1" then
        cursor:set("tod","mobiled_backup","enabled", "0")
        cursor:commit("tod")
        if network_mode == "Mobiled_scheduled" then
            cursor:set("wansensing","global","network_mode", "Fixed_line")
            cursor:commit("wansensing")
            -- disable 3G/4G
            failoverhelper.mobiled_enable(runtime, "0")
        end
    end
    return true
end

-- stop action
function M.stop(runtime, actionname, object)
    return true
end

return M
