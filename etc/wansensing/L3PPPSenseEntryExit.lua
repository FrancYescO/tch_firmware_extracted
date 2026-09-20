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


    if l2type == "ADSL" then
         x:set("network", "ppp", "ifname", "atm_ppp")
        x:set("network", "ipoe", "ifname", "atm_ipoe")
        x:delete("network", "ppp", "auto")
        x:delete("network", "ipoe", "auto")
    elseif l2type == "VDSL" then
        x:delete("network", "ppp", "ifname")
        x:set("network", "ipoe", "ifname", "ptm0")
        x:set("network", "pppv", "ifname","vlan_ppp")
        x:set("network", "vlan_ppp", "ifname", "ptm0")
        x:set("network", "ppp", "auto","0")
        x:delete("network", "ipoe", "auto")
        x:delete("network", "pppv", "auto")
        x:delete("network", "vlan_ppp", "auto")
        x:set("network", "vlan_hfc", "auto", "0")
    elseif l2type == "ETH" then
        x:delete("network", "ppp", "ifname")
        x:set("network", "ipoe", "ifname", "eth4")
        x:set("network", "pppv", "ifname", "vlan_hfc")
        x:set("network", "vlan_hfc", "ifname", "eth4")
        x:set("network", "ppp", "auto","0")
        x:delete("network", "ipoe", "auto")
        x:delete("network", "pppv", "auto")
        x:delete("network", "vlan_hfc", "auto")
        x:set("network", "vlan_ppp", "auto", "0")
    end

    x:commit("network")

    os.execute("sleep 2")
    conn:call("network", "reload", { })
    conn:call("network.interface.pppv", "up", { })
    conn:call("network.interface.ipoe", "up", { })


    return true
end

function M.exit(runtime,l2type, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 PPP Sense exit script is using transition " .. transition .. " using l2type " .. tostring(l2type))

    return true
end

return M
