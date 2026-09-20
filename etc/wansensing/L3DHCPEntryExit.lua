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
    runtime.l3dhcp_failures_v4 = 0
    runtime.l3dhcp_failures_v6 = 0
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

    -- bring up the wan and wan6 intf here
    conn:call("network.interface.wan", "up", { })
    conn:call("network.interface.wan6", "up", { })

    -- first kill the currently possible running bfdecho daemons
    os.execute("killall -9 bfdecho.lua 2>/dev/null")
    local mode = x:get("wansensing", "global", "supervision_mode")
    if mode == "BFD" then
       local v4enable = x:get("bfdecho", "bfdecho_config", "ipv4_enabled")
       local v6enable = x:get("bfdecho", "bfdecho_config", "ipv6_enabled")
       if v4enable == "enabled" then
          -- start IPv4 BFD echo daemon with wan intf
          logger:notice("Starting IPv4 BFD Echo daemon ...")
          os.execute("/usr/bin/bfdecho.lua wan ipv4 &")
       end
       if v6enable == "enabled" then
          -- start IPv6 BFD echo daemon with wan6 intf
          logger:notice("Starting IPv6 BFD Echo daemon ...")
          os.execute("/usr/bin/bfdecho.lua wan6 ipv6 &")
       end
    end
    runtime.mode = mode

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

    local x = uci.cursor()
    local mode = x:get("wansensing", "global", "supervision_mode")
    if mode == "BFD" then
       local v4enable = x:get("bfdecho", "bfdecho_config", "ipv4_enabled")
       local v6enable = x:get("bfdecho", "bfdecho_config", "ipv6_enabled")
       if v4enable == "enabled" or v6enable == "enabled" then
          -- stop IPv4/IPv6 BFD echo daemon
          logger:notice("Stopping BFD Echo daemon ...")
          os.execute("killall -9 bfdecho.lua 2>/dev/null")
       end
    end

    return true
end

return M
