local M = {}

function M.entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 entry script is configuring PPP and DHCP on l2type interface " .. tostring(l2type))

    -- setup sensing config on ipoe and ppp interfaces
    local x = uci.cursor()
    local user = x:get("network", "ppp", "username")

    -- copy ipoe sense interfaces to wan interface
    x:set("network", "ipoe", "auto", "0")
    x:commit("network")
    conn:call("network", "reload", { })

    scripthelpers.delete_interface("wan")
    scripthelpers.copy_interface("ipoe", "wan")
    x:delete("network", "ipoe", "ifname")
    x:commit("network")
    conn:call("network", "reload", { })

    if l2type == "ADSL" then
        x:set("network", "ppp", "ifname", "atm_8_35")
        x:set("network", "wan", "ifname", "atm_8_35")
        x:set("ethoam", "global", "enable", "0")
    elseif l2type == "VDSL" then
        x:set("network", "ppp", "ifname", "ptm0")
        x:set("network", "wan", "ifname", "ptm0")
        x:set("ethoam", "global", "enable", "1")
        x:set("ethoam", "config1", "ifname", "ptm0")
        x:set("ethoam", "config2", "ifname", "ptm0")
        x:set("ethoam", "config3", "ifname", "ptm0")
    elseif l2type == "ETH" then
        x:set("network", "ppp", "ifname", "eth4")
        x:set("network", "wan", "ifname", "eth4")
        x:set("ethoam", "global", "enable", "1")
        x:set("ethoam", "config1", "ifname", "eth4")
        x:set("ethoam", "config2", "ifname", "eth4")
        x:set("ethoam", "config3", "ifname", "eth4")
    end

    x:commit("ethoam")
    os.execute("/etc/init.d/ethoam reload")

    if user ~= nil then
		x:delete("network", "ppp", "auto")
    end
	x:delete("network", "wan", "auto")

    x:commit("network")
    --the WAN interface is defined --> create the xtm queues
    if l2type == 'ADSL' or l2type == 'VDSL' then
       os.execute("/etc/init.d/xtm restart")
    end

	os.execute("sleep 2")
    conn:call("network", "reload", { })
    if user ~= nil then
		conn:call("network.interface.ppp", "up", { })
    end
    conn:call("network.interface.wan", "up", { })
    return true
end

function M.exit(runtime,l2type, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 exit script is using transition " .. transition .. " using l2type " .. tostring(l2type))

    return true
end

return M
