local M = {}
local xdslctl = require('transformer.shared.xdslctl')
local failoverhelper = require('wansensingfw.failoverhelper')
local match = string.match

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wwan_ifup',
}

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
function M.check(runtime, l2type, event)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth
    local status

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 main script is sensing PPP and DHCP on l2type interface " .. tostring(l2type))

    if event == "timeout" then
        -- start sensing
        --sense DHCP on both wan and wan6 interface
        if scripthelpers.checkIfInterfaceIsUp("wan") or scripthelpers.checkIfInterfaceHasIP("wan6", true) then
            logger:notice("The L3 main script sensed DHCP on l2type interface " .. tostring(l2type))
            return "L3DHCP"
        end
        --sense PPP
        if scripthelpers.checkIfInterfaceIsUp("ppp") then
            logger:notice("The L3 main script sensed PPP on l2type interface " .. tostring(l2type))
            return "L3PPP"
        end
    else
        if l2type == 'ETH' then
            if not scripthelpers.l2HasCarrier("eth4") then
                return "L2Sense"
            end
        elseif scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
            return "L2Sense"
        end
    end

    local x = uci.cursor()
    local autofailover = x:get("wansensing", "global", "autofailover")

    runtime.ltebackup_delay_counter = runtime.ltebackup_delay_counter or 0
    logger:notice("LTE counter " .. tostring(runtime.ltebackup_delay_counter))

    if runtime.ltebackup_delay_counter > 11 then
        if l2type == 'ETH' then
            -- if ETH still cannot get an IP address, check if DSL is up
            local mode = xdslctl.infoValue("tpstc")
            logger:notice("mode " .. tostring(mode))
            if mode then
                if match(mode, "ATM") or match(mode, "PTM") then
                    return "L2Sense"
                end
            end
            if runtime.ltebackup_delay_counter > 19 then
                if autofailover == "1" then
                    -- we need to delay bringing up the mobile interface
                    -- to make sure the synchonization of l3 is completed
                    -- enable 3G/4G
                    failoverhelper.mobiled_enable(runtime, "1", "wwan")
                end
            else
                runtime.ltebackup_delay_counter = runtime.ltebackup_delay_counter + 1
            end
        elseif autofailover == "1" then
            -- we need to delay bringing up the mobile interface
            -- to make sure the synchonization of l3 is completed
            -- enable 3G/4G
            failoverhelper.mobiled_enable(runtime, "1", "wwan")
        end
    else
        runtime.ltebackup_delay_counter = runtime.ltebackup_delay_counter + 1
    end

    return "L3Sense"
end

return M


