local M = {}
local xdslctl = require('transformer.shared.xdslctl')
local match = string.match
local open = io.open

function M.check(runtime)
    local scripthelpers = runtime.scripth
    local uci = runtime.uci
    local value
    local fd
    local L2

    if not uci then
        return false
    end

    -- check if wan ethernet port is up
    if scripthelpers.l2HasCarrier("eth4") then
       return "L3Sense", "ETH"
    end

    -- check if xDSL is up
    local mode = xdslctl.infoValue("tpstc")
    if mode then
        if match(mode, "ATM") then
            return "L3Sense", "ADSL"
        elseif match(mode, "PTM") then
            return "L3Sense", "VDSL"
        end
     end

     return "L2Sense"
end

return M
