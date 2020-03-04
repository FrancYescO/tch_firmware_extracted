local M = {}

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wan_ifup',
    'network_interface_ppp_ifup',
    'network_interface_ipoe_ifup',
}

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
local function non_novas_check(runtime, l2type, event)
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
        if scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
            return "L2Sense"
        end
    end
    return "L3Sense"
end

local function novas_check(runtime, l2type, event)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth
    local status

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 main script is sensing PPP and DHCP on l2type interface " .. tostring(l2type))

    if event == "timeout" or event == "network_interface_wan_ifup" or event == "network_interface_ppp_ifup" or event == "network_interface_ipoe_ifup" then
        if scripthelpers.checkIfInterfaceIsUp("wan") then
            logger:notice("The L3 main script sensed PPP VLAN 2 on l2type interface " .. tostring(l2type))
            return "L3PPPV"
        end
        if scripthelpers.checkIfInterfaceIsUp("ppp") then
            logger:notice("The L3 main script sensed PPP no VLAN on l2type interface " .. tostring(l2type))
            return "L3PPPSense"
        end
        if scripthelpers.checkIfInterfaceIsUp("ipoe") then
            logger:notice("The L3 main script sensed DHCP on l2type interface " .. tostring(l2type))
            return "L3DHCP"
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
    return "L3Sense"
end

function M.check(runtime, l2type, event)
    if runtime.variant == "novas" then
        return novas_check(runtime, l2type, event)
    else
        return non_novas_check(runtime, l2type, event)
    end
end

return M


