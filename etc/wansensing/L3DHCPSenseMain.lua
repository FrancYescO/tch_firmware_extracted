local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wwan_ifup',
}

local events = {
    timeout = true,
    network_interface_wwan_ifup = true,
}

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
function M.check(runtime, l2type, event)
    local uci = runtime.uci
    local conn = runtime.ubus
    local x = uci.cursor()
    local logger = runtime.logger
    local scripthelpers = runtime.scripth
    local status

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 DHCP Sense script is sensing DHCP on l2type interface " .. tostring(l2type))

    if events[event] then
        -- start sensing
        --sense DHCP
        if scripthelpers.checkIfInterfaceIsUp("wan") or scripthelpers.checkIfInterfaceHasIP("wan6",true) then
            logger:notice("The L3 DHCP Sense script sensed DHCP on l2type interface " .. tostring(l2type))
            return "L3DHCP"
        end
        runtime.l3dhcp_failures = runtime.l3dhcp_failures + 1
        logger:notice("DHCP check No " .. tostring(runtime.l3dhcp_failures))
        if runtime.l3dhcp_failures > 59 then
            -- after 5 minutes, restart looking for ppp as well as dhcp
            return "L3Sense"
        else
            local autofailover = x:get("wansensing", "global", "autofailover")
            if autofailover == "1" then
                -- enable 3G/4G
                failoverhelper.mobiled_enable(runtime, "1", "wwan")
            end
            return "L3DHCPSense"
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


