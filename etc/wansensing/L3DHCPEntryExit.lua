local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')

function M.entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3DHCP entry script is configuring DHCP on wan and wan6 interface on l2type interface " .. tostring(l2type))

    -- initialize failures counter
    runtime.l3dhcp_failures = 0
    local x = uci.cursor()

    -- disable ppp and set interface to something other than the active interface
    x:set("network", "ppp", "auto", "0")
    if l2type == "ETH" then
        x:set("network", "ppp", "ifname", "atm_8_35")
    else
        x:set("network", "ppp", "ifname", "eth4")
    end

    x:commit("network")
    conn:call("network", "reload", { })

    return true
end

function M.exit(runtime,l2type, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    failoverhelper.revert_provisioning_code(runtime)
    logger:notice("The L3DHCP exit script is using transition " .. transition .. " using l2type " .. tostring(l2type))

    return true
end

return M
