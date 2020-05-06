local M = {}
local xdslctl = require('transformer.shared.xdslctl')
local match = string.match
local popen = io.popen
local failoverhelper = require('wansensingfw.failoverhelper')

function M.check(runtime, event)
    local scripthelpers = runtime.scripth
    local uci = runtime.uci
	local logger = runtime.logger
    local L2 = nil
	local x = uci.cursor()
	local sfp_try = 0

    if not uci then
        return false
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
    -- no xDSL link then check ethernet link
    if L2 == nil then
        -- check if wan ethernet port is up
        if scripthelpers.l2HasCarrier("eth4") then
		-- SFP p2p/gpon scenario to check sfpi2cctl can get correct venername
	    local ctl = popen("/usr/sbin/sfpi2cctl -get -format vendname")
            if ctl then
                local output = ctl:read("*a")
                logger:notice("The L2 Checking : output from SFP-->" .. tostring(output))
                local vendname = match(output, "^.+:%[(.+)%]")
                ctl:close()
                if vendname ~= nil then
                    L2 = "FIBER"
                    local eth4lanwanmode = x:get("ethernet", "globals", "eth4lanwanmode")
                    if eth4lanwanmode and eth4lanwanmode ~= "1" then
                        -- SFP p2p/gpon scenario need recover eth4 to lan port
                        x:set("ethernet", "globals", "eth4lanwanmode", "1")
                        x:commit("ethernet")
                        os.execute("/etc/init.d/ethernet reload")
                    end

                    -- SFP p2p/gpon scenario disable xdsl to save resource
                    os.execute("/etc/init.d/xdsl stop")
                else
                    runtime.sfp_check_counter = runtime.sfp_check_counter or 0
                    if runtime.sfp_check_counter > 5 then
                        L2 = "ETH"
                    else
                        logger:notice("The L2 Checking : try of sfp " .. tostring(runtime.sfp_check_counter))
                        runtime.sfp_check_counter = runtime.sfp_check_counter + 1
                    end
                end
            end
        end
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
    else
        if mode ~= "Fixed_line" then
            -- we need to check the previous L2 connection to set the delay_counter
            local origL2 = x:get("wansensing", "global", "l2type")
            local ltebackup_delay_counter_value = 19
            if origL2 == "ADSL" or origlL2 == "VDSL" then
                ltebackup_delay_counter_value = 14
            elseif origL2 == "ETH" or origL2 == "FIBER" then
                ltebackup_delay_counter_value = 9
            end

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
    end

    return "L2Sense"
end

return M

