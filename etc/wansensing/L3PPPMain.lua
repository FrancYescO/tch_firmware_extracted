local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wan_ifup',
    'network_interface_wwan_ifup',
    'network_interface_wwan_ifdown',
}

local events = {
    timeout = true,
    network_interface_wan_ifup = true,
    network_interface_wwan_ifup = true,
    network_interface_wwan_ifdown = true,
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

    logger:notice("The L3PPP main script is checking link connectivity and DHCP on l2type interface " .. tostring(l2type))

    if events[event] then
        --sense IPoE or wan6
        if scripthelpers.checkIfInterfaceIsUp("ipoe") or scripthelpers.checkIfInterfaceHasIP("wan6", true) then
            runtime.l3ppp_failures = 0
            return "L3DHCPSense"
        end

        --sense WAN which is PPP at this moment
        if scripthelpers.checkIfInterfaceIsUp("wan") then
            -- disable 3G/4G
            failoverhelper.mobiled_enable(runtime, "0", "wwan")
            runtime.l3ppp_failures = 0
            return "L3PPP"
        end

        local x = uci.cursor()
        local autofailover = x:get("wansensing", "global", "autofailover")
        if autofailover == "1" then
           -- enable 3G/4G, if the interface is not up, should wait for another 60 secs
            runtime.l3ppp_failures = runtime.l3ppp_failures or 0
            if runtime.l3ppp_failures < 1 then
                runtime.l3ppp_failures = runtime.l3ppp_failures + 1
                return "L3PPP"
            else
                failoverhelper.mobiled_enable(runtime, "1", "wwan")
            end
        end
        return "L3PPP"
    else
        if l2type == 'ETH' then
			if not scripthelpers.l2HasCarrier("eth4") then
				return "L2Sense"
			end
		elseif scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
			return "L2Sense"
		end

        runtime.l3ppp_failures = 0
        return "L3PPP" -- if we get there, then we're not concerned, the non used L2 went down
    end
end

return M
