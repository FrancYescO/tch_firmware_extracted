local M = {}

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down'
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
        --sense DHCP
        if scripthelpers.checkIfInterfaceIsUp("ipoe") then
            logger:notice("The L3 main script sensed DHCP on l2type interface " .. tostring(l2type))
            return "L3DHCP"
        end
        --sense PPP
        if scripthelpers.checkIfInterfaceIsUp("ppp") then
            logger:notice("The L3 main script sensed PPP on l2type interface " .. tostring(l2type))
            return "L3PPP"
        end
    else
        if scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
            return "L2Sense"
        end
    end
    return "L3Sense"
end

return M


