local M = {}

function M.entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 entry script is configuring PPP and DHCP on l2type interface " .. tostring(l2type))

    -- setup sensing config on ipoe and ppp interfaces
    local x = uci.cursor()

    x:delete("network", "wan")
    x:set("network", "wan", "interface")
    x:set("network", "wan", "auto","0")

    if l2type == "ADSL" then
        x:set("network", "ppp", "ifname", "atm_ppp")
        x:set("network", "ipoe", "ifname", "atm_ipoe")
        x:set("network", "video", "ifname", "atm_video")
        x:set("network", "video2", "ifname", "atm_video2")
        x:delete("network", "video", "auto")
        x:delete("network", "video2", "auto")
    elseif l2type == "VDSL" then
        x:set("network", "vlan_ppp", "ifname", "ptm0")
        x:set("network", "vlan_video", "ifname", "ptm0")
        x:set("network", "pppv", "ifname", "vlan_ppp")
        x:set("network", "ppp", "ifname", "ptm0")
        x:set("network", "ipoe", "ifname", "ptm0")
        x:set("network", "video", "ifname", "vlan_video")
        x:delete("network", "video", "auto")
        x:delete("network", "video2", "ifname")
        x:set("network", "video2", "auto", "0")
    elseif l2type == "ETH" then
        x:set("network", "ppp", "ifname", "eth4")
        x:set("network", "ipoe", "ifname", "eth4")
        x:delete("network", "video", "type")
        x:delete("network", "video", "ifname")
        x:set("network", "video", "auto","0")
        x:delete("network", "video2", "ifname")
        x:set("network", "video2", "auto","0")
    end

    x:delete("network", "ppp", "auto")
    x:delete("network", "pppv", "auto")
    x:delete("network", "ipoe", "auto")

    x:commit("network")
    conn:call("network", "reload", { })
    conn:call("network.interface.ppp", "up", { })
    conn:call("network.interface.pppv", "up", { })
    conn:call("network.interface.ipoe", "up", { })
    conn:call("network.interface.video", "up", { })
    conn:call("network.interface.video2", "up", { })

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
