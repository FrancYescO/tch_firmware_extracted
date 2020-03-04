local M = {}

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wan_ifdown',
    'network_interface_ipoe_ifup',
}

local function PPPFailReason(conn, intf)
   local status = conn:call("network.interface." .. intf, "status", { })
   return status and status.errors and status.errors[1] and status.errors[1].code
end

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

    logger:notice("The L3PPP main script is checking link connectivity and DHCP on l2type interface " .. tostring(l2type))

    if event == "timeout" then
        --sense WAN which is PPPV at this moment
        if scripthelpers.checkIfInterfaceIsUp("wan") then
            runtime.l3ppp_failures = 0
            return "L3PPPV"
        end
        runtime.l3ppp_failures = runtime.l3ppp_failures or 0
        runtime.l3ppp_failures = runtime.l3ppp_failures + 1
        if runtime.l3ppp_failures > 3 then
            return "L3PPPVSense"
        else
            return "L3PPPV", true -- do next check using fasttimeout rather than timeout
        end
    else
        if scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
            if PPPFailReason(conn, 'wan') == 'AUTH_TOPEER_FAILED' then
                return "L3PPPV"
            else
                return "L2Sense"
            end
        end
        return "L3PPPV" -- if we get there, then we're not concerned, the non used L2 went down
    end
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

    logger:notice("The L3PPPV main script is sensing PPP and DHCP on l2type interface " .. tostring(l2type))

    if event == "timeout" or event == "network_interface_wan_ifdown" or event == "network_interface_ipoe_ifup" then
        if scripthelpers.checkIfInterfaceIsUp("ipoe") then
            logger:notice("The L3PPPV main script sensed DHCP VLAN 6 on l2type interface " .. tostring(l2type))
            return "L3DHCP"
        end
        return "L3PPPV"
	else
        if l2type == 'ETH' then
            if not scripthelpers.l2HasCarrier("eth4") then
                return "L2Sense"
            end
        elseif scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
            return "L2Sense"
        end
    end
    return "L3PPPV"
end

function M.check(runtime, l2type, event)
    if runtime.variant == "novas" then
        return novas_check(runtime, l2type, event)
    else
        return non_novas_check(runtime, l2type, event)
    end
end

return M


