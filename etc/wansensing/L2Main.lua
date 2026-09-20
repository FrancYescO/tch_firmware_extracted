local M = {}
local xdslctl = require('transformer.shared.xdslctl')
local failoverhelper = require('wansensingfw.failoverhelper')
local match = string.match
M.SenseEventSet = {
    'network_interface_wwan_ifup',
}

function M.check(runtime)
    local scripthelpers = runtime.scripth
    local uci = runtime.uci
    local x = uci.cursor()
    local logger = runtime.logger
    local value
    local fd
    local L2
    -- send l2 wansensing start event
    local conn = runtime.ubus
    if not conn then
        return false
    end
    conn:send('Layer2.wansensing', { status = 'starting'})
    if not uci then
        return false
    end

    -- check if wan ethernet port is up
    if scripthelpers.l2HasCarrier("eth4") then
        L2 = "ETH"
        x:set("ethoam", "global", "enable", "0")
        x:commit("ethoam")
    end

    -- check if xDSL is up
    local mode = xdslctl.infoValue("tpstc")
    if mode then
        if match(mode, "ATM") then
            L2 = "ADSL"
            x:set("ethoam", "global", "enable", "0")
            x:commit("ethoam")
        elseif match(mode, "PTM") then
            L2 = "VDSL"
            x:set("ethoam", "global", "enable", "1")
            x:commit("ethoam")
        end
    end
    logger:notice("L2Main.lua: check interface PHY type " .. tostring(L2))

    -- If there was already an L3 mode configured and the L2 did not change, then we go for it
    -- otherwise, go in L3 sensing mode
    local origL2 = x:get("wansensing", "global", "l2type")
    if L2 then
        local origL3 = x:get("wansensing", "global", "l3type")
        if L2 == origL2 and origL3 and string.len(origL3) > 0 then
            logger:notice("L2Main.lua: interface origL3 " .. tostring(origL3))
            return origL3, L2
        else
            return "L3Sense", L2
        end
    end

    local autofailover = x:get("wansensing", "global", "autofailover")
    if autofailover == "1" then
        -- we need to check the previous L2 connection to set the delay_counter
        local ltebackup_delay_counter_value = 19
        if origL2 == "ADSL" then
            ltebackup_delay_counter_value = 14
        elseif origL2 == "ETH" then
            ltebackup_delay_counter_value = 9
        end

        -- we need to delay bringing up the mobile interface
        -- to make sure the synchonization of l2 is completed
        runtime.ltebackup_delay_counter = runtime.ltebackup_delay_counter or 0
        if runtime.ltebackup_delay_counter > ltebackup_delay_counter_value then
            failoverhelper.revert_provisioning_code(runtime)
            -- enable 3G/4G
            failoverhelper.mobiled_enable(runtime, "1", "wwan")
        else
            runtime.ltebackup_delay_counter = runtime.ltebackup_delay_counter + 1
        end
    end

    return "L2Sense"
end

return M
