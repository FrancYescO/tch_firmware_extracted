local M = {}
local match = string.match
local popen = io.popen
local failoverhelper = require('wansensingfw.failoverhelper')
local optical = require("transformer.shared.optical")

function M.check(runtime, event)
    local scripthelpers = runtime.scripth
    local uci = runtime.uci
    local L2
    local x = uci.cursor()

    if not uci then
        return false
    end

    if optical.getGponstate() == "Up" then
        L2 = "GPON"
    end

    local mode = x:get("wansensing", "global", "network_mode")
    if mode == "Mobiled_scheduled" then
        failoverhelper.tod_config(runtime, "1")
    else
        failoverhelper.tod_config(runtime, "0")
    end
    if mode == "Fixed_line" then
        -- Disable mobile
        failoverhelper.mobiled_enable(runtime, "0")
    end

    if L2 then
        return "L3Sense", L2
    elseif mode == "auto" then
        -- we need to check the previous L2 connection to set the delay_counter
        local ltebackup_delay_counter_value = 9
    
        -- we need to delay bringing up the mobile interface
        -- to make sure the synchonization of l2 is completed
        runtime.ltebackup_delay_counter = runtime.ltebackup_delay_counter or 0
        if runtime.ltebackup_delay_counter > ltebackup_delay_counter_value then
            -- enable 3G/4G
            failoverhelper.mobiled_enable(runtime, "1")
        else
            runtime.ltebackup_delay_counter = runtime.ltebackup_delay_counter + 1
        end
    end

    return "L2Sense"
end

return M

