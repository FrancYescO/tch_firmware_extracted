local M = {}
local xdslctl = require('transformer.shared.xdslctl')
local match = string.match

local function non_novas_check(runtime)
    local scripthelpers = runtime.scripth
    local uci = runtime.uci
    local value
    local L2

	local L3Entry = {
        L3PPP = "L3PPP",
        L3PPPSense = "L3PPP",
        L3PPPV = "L3PPPV",
        L3PPPVSense = "L3PPPV",
        L3DHCP = "L3DHCP",
        L3DHCPSense = "L3DHCP"
    }

    if not uci then
        return false
    end

    -- check if wan ethernet port is up
    if scripthelpers.l2HasCarrier("eth4") then
      L2 = "ETH"
    else
        -- check if xDSL is up
        local mode = xdslctl.infoValue("tpstc")
        if mode then
            if match(mode, "ATM") then
                L2 = "ADSL"
            elseif match(mode, "PTM") then
                L2 = "VDSL"
            end
        end
    end

    -- If there was already an L3 mode configured and the L2 did not change, then we go for it
    -- otherwise, go in L3 sensing mode
    if L2 then
        local x = uci.cursor()
        local origL2 = x:get("wansensing", "global", "l2type")
        local origL3 = x:get("wansensing", "global", "l3type")

        if L2 == origL2 and origL3 and string.len(origL3) > 0 then
            if L3Entry[origL3] then
                return L3Entry[origL3], L2
            else
                return origL3, L2
            end
        else
            return "L3DHCP", L2
        end
    end

    return "L2Sense"
end

local function novas_check(runtime)
    local scripthelpers = runtime.scripth
    local uci = runtime.uci
    local value
    local L2

	local L3Entry = {
        L3PPP = "L3PPPSense",
        L3PPPSense = "L3PPPSense",
        L3DHCP = "L3Sense",
        L3PPPV = "L3Sense",
        L3Sense = "L3Sense"
    }

    if not uci then
        return false
    end

    -- check if wan ethernet port is up
    if scripthelpers.l2HasCarrier("eth4") then
      L2 = "ETH"
    else
        -- check if xDSL is up
        local mode = xdslctl.infoValue("tpstc")
        if mode then
            if match(mode, "ATM") then
                L2 = "ADSL"
            elseif match(mode, "PTM") then
                L2 = "VDSL"
            end
        end
    end

    -- If there was already an L3 mode configured and the L2 did not change, then we go for it
    -- otherwise, go in L3 sensing mode
    if L2 then
        local x = uci.cursor()
        local origL2 = x:get("wansensing", "global", "l2type")
        local origL3 = x:get("wansensing", "global", "l3type")

        if L2 == origL2 and L2 == "ETH" and origL3 and string.len(origL3) > 0 then
            if L3Entry[origL3] then
                return L3Entry[origL3], L2
            else
                return L3Sense, L2
            end
        else
            return "L3Sense", L2
        end
    end

    return "L2Sense"
end

function M.check(runtime)
    if not runtime.variant then
        local uci = runtime.uci
        local x = uci.cursor()
        runtime.variant = x:get("env","var","iinet_variant")
    end
    if runtime.variant == "novas" then
        return novas_check(runtime)
    else
        return non_novas_check(runtime)
    end
end

return M
