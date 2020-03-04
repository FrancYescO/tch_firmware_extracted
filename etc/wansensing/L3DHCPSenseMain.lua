local M = {}

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down'
}

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--e.g. ADSL,VDSL,ETH
function M.check(runtime, l2type, event)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth
    local status

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 DHCP Sense script is sensing DHCP and PPP on l2type interface " .. tostring(l2type))

    local x = uci.cursor()
    if event == "timeout" then
        -- start sensing
        --sense DHCP
        if scripthelpers.checkIfInterfaceIsUp("wan") then
            logger:notice("The L3 DHCP Sense script sensed DHCP on l2type interface " .. tostring(l2type).."  IP addr = ".. tostring(wanipaddr))
            return "L3DHCP"
        end
        --sense PPP on VLAN
        if scripthelpers.checkIfInterfaceIsUp("pppv") then
            logger:notice("The L3 main script sensed PPP VLAN on l2type interface " .. tostring(l2type))
            return "L3PPPV"
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
    return "L3DHCPSense"
end

return M


