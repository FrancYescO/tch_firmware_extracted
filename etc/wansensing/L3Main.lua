local M = {}

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down'
}

local function setWanConfig(runtime, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local x = uci.cursor()
    local ifname=x:get("network", "wan", "ifname")

    if ifname == nil and (transition == "ppp_8_35" or transition == "ppp_8_81") then
        local transition_ifname = x:get("network", transition, "ifname")
        x:set("network", "ppp_8_35", "auto", "0")
        x:set("network", "ppp_8_81", "auto", "0")

        x:set("network", "wan", "proto", "pppoe")
        x:set("network", "wan", "ifname", transition_ifname)
        x:set("network", "wan", "auto", "1")

        x:commit("network")
        conn:call("network", "reload", { })

        collectgarbage("collect")
        collectgarbage("collect")
    end
end

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
--event = specifies the event which triggered this check method call (eg. timeout, xdsl_0)
function M.check(runtime, l2type, event)
    local scripthelpers = runtime.scripth
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    --logger:notice("The L3 main script is sensing on l2type interface " .. tostring(l2type))

    if event == "timeout"  then
        if l2type == "ADSL" then
            -- start sensing
            --sense ppp_8_35
            if scripthelpers.checkIfInterfaceIsUp("ppp_8_35") then
                --logger:notice("The L3 main ppp_8_35 sensed PPP on l2type interface " .. tostring(l2type))
                setWanConfig(runtime, "ppp_8_35")
                return "L3Sense"
            end
            --sense ppp_8_81
            if scripthelpers.checkIfInterfaceIsUp("ppp_8_81") then
                --logger:notice("The L3 main ppp_8_81 sensed PPP on l2type interface " .. tostring(l2type))
                setWanConfig(runtime, "ppp_8_81")
                return "L3Sense"
            end

            local x = uci.cursor()
            local wan_username = x:get("network", "wan", "username")
            local wan_password = x:get("network", "wan", "password")
            local ppp_username = x:get("network", "ppp_8_35", "username")
            local ppp_password = x:get("network", "ppp_8_35", "password")

            collectgarbage("collect")
            collectgarbage("collect")

            -- if the username and password is changed, go to L2Sense then L3Sense entry to copy
            -- the username/password to interfaces ppp_8_35 and ppp_8_81
            if wan_username ~= ppp_username or wan_password ~= ppp_password then
                return "L2Sense"
            else
                return "L3Sense"
            end
        end

        return "L3Sense"
    end

    return "L2Sense"
end

return M

