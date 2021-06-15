local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')

function M.entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth
    local x = uci.cursor()

    runtime.l3dhcp_renew_delay_timer_v4 = nil
    runtime.l3dhcp_renew_wait_timer_v4 = nil
    runtime.l3dhcp_renew_delay_timer_v6 = nil
    runtime.l3dhcp_renew_wait_timer_v6 = nil

    runtime.dns_wan_ok = true
    runtime.dns_wan6_ok = true

    runtime.l3dhcp_failures = 0

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3DHCP entry script is configuring DHCP on wan and wan6 interface on l2type interface " .. tostring(l2type))

    -- disable ppp and set interface to something other than the active interface
    x:set("network", "ppp", "auto", "0")
    if l2type == "ETH" then
        x:set("network", "ppp", "ifname", "atm_8_35")
    else
        x:set("network", "ppp", "ifname", "eth4")
    end

    x:commit("network")
    conn:call("network", "reload", { })

    os.execute("test -f /usr/bin/queue-resize.sh && sh /usr/bin/queue-resize.sh")

    -- trigger supervision
    logger:notice("Starting supervision ...")
    conn:call("supervision", "start", { })

    return true
end

function M.exit(runtime,l2type, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    runtime.l3dhcp_renew_delay_timer_v4 = nil
    runtime.l3dhcp_renew_wait_timer_v4 = nil
    runtime.l3dhcp_renew_delay_timer_v6 = nil
    runtime.l3dhcp_renew_wait_timer_v6 = nil

    failoverhelper.revert_provisioning_code(runtime)
    logger:notice("The L3DHCP exit script is using transition " .. transition .. " using l2type " .. tostring(l2type))

    -- stop supervision
    logger:notice("Stopping supervision ...")
    conn:call("supervision", "stop", { })

    return true
end

return M
