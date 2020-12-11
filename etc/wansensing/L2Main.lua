local M = {}
local xdslctl = require('transformer.shared.xdslctl')
local match = string.match

function M.check(runtime)
    local scripthelpers = runtime.scripth
    local uci = runtime.uci
    local x = uci.cursor()
    local L2

    if not uci then
        return false
    end

    -- check if wan ethernet port is up
    if scripthelpers.l2HasCarrier("eth4") then
        L2 = "ETH"
    end

    -- check if xDSL is up
    local mode = xdslctl.infoValue("tpstc")
    if mode then
        if match(mode, "ATM") then
            L2 = "ADSL"
        elseif match(mode, "PTM") then
            L2 = "VDSL"
        end
    end

    -- If there was already an L3 mode configured and the L2 did not change, then we go for it
    -- otherwise, go in L3 sensing mode
    if L2 then
        local origL2 = x:get("wansensing", "global", "l2type")
        local origL3 = x:get("wansensing", "global", "l3type")

        if L2 == origL2 and origL3 and string.len(origL3) > 0 then
            return origL3, L2
        else
            return "L3Sense", L2
        end
    end


    return "L2Sense"
end

return M
