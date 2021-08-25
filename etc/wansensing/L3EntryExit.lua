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
    local xlat = x:get("network", "wan6", "iface_464xlat")

    -- initialize lteback_delay_counter
    runtime.ltebackup_delay_counter = 0

    -- copy ipoe sense interfaces to wan interface
    x:set("network", "ipoe", "auto", "0")

    scripthelpers.delete_interface("wan")
    scripthelpers.copy_interface("ipoe", "wan")
    x:delete("network", "ipoe", "ifname")
    x:commit("network")

    if l2type == "ADSL" then
        x:set("network", "ppp", "ifname", "atm_8_35")
        x:set("network", "wan", "ifname", "atm_8_35")
        x:set("network", "wan6", "ifname", "atm_8_35")
    elseif l2type == "VDSL" then
        x:set("network", "ppp", "ifname", "ptm0")
        x:set("network", "wan", "ifname", "ptm0")
        x:set("network", "wan6", "ifname", "ptm0")
    elseif l2type == "ETH" then
        x:set("network", "ppp", "ifname", "eth4")
        x:set("network", "wan", "ifname", "eth4")
        x:set("network", "wan6", "ifname", "eth4")
    end

    if xlat == "0" then
        if user then
            x:delete("network", "ppp", "auto")
        end
        x:delete("network", "wan", "auto")
    else
        x:set("network", "ppp", "auto", "0")
        x:set("network", "wan", "auto", "0")
    end
    x:delete("network", "wan6", "auto")

    x:commit("network")

    conn:call("network", "reload", { })
    if xlat == "0" then
        if user then
            conn:call("network.interface.ppp", "up", { })
        end
        conn:call("network.interface.wan", "up", { })
    end
    conn:call("network.interface.wan6", "up", { })

    os.execute("/etc/init.d/ethoam reload")
    os.execute("test -f /usr/bin/queue-resize.sh && sh /usr/bin/queue-resize.sh")

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
