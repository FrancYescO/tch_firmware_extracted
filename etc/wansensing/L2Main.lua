local M = {}
local xdslctl = require('transformer.shared.xdslctl')
local match = string.match
local open = io.open

function M.check(runtime)
   local uci = runtime.uci
   local scripthelpers = runtime.scripth
   local sensedL2
   local nextL3state

    -- check if wan ethernet port is up
    if scripthelpers.l2HasCarrier("eth4") then
       sensedL2 = "ETH"
       nextL3state = "L3SingleWan"
    end

    -- check if xDSL is up
    local mode = xdslctl.infoValue("tpstc")
    if mode then
       if match(mode, "ATM") then
          sensedL2 = "ADSL"
          nextL3state = "L3VoipSense" 
        elseif match(mode, "PTM") then
           sensedL2 = "VDSL"
           nextL3state = "L3MultiWan"
        end
     end

     if sensedL2 then
        -- If there was already a layer3 type configured and the sensed physical layer did not change, 
        -- then we go for this layer3 type
        -- otherwise, go in L3 sensing mode
        local x = uci.cursor()
        local origL2 = x:get("wansensing", "global", "l2type")
        local origL3 = x:get("wansensing", "global", "l3type")

        if sensedL2 == origL2 and origL3 and string.len(origL3) > 0 then
            nextL3state = origL3
        end
        
        return nextL3state, sensedL2
     end

     return "L2Sense"
end

return M
