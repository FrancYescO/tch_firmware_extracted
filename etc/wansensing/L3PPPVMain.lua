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

    -- iiNet only set InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.Username
    -- and            InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.Password
    -- need to copy the values from network.wan to network.ppp and network.pppv
    local x = uci.cursor()
    local wanUsername = x:get("network", "wan", "username")
    local pppUsername = x:get("network", "ppp", "username")
    if wanUsername ~= pppUsername then
        logger:notice("The L3PPPV main script is copying the username and password from wan to ppp and pppv")
        local wanPassword = x:get("network", "wan", "password")
        x:set("network", "ppp", "username", wanUsername)
        x:set("network", "pppv", "username", wanUsername)
        x:set("network", "ppp", "password", wanPassword)
        x:set("network", "pppv", "password", wanPassword)
        x:commit("network")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
    end

    logger:notice("The L3PPPV main script is checking link connectivity on l2type interface " .. tostring(l2type))

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
            return "L2Sense"
        end
        runtime.l3ppp_failures = 0
        return "L3PPPV" -- if we get there, then we're not concerned, the non used L2 went down
    end
end

return M


