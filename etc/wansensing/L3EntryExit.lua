local M = {}

local function non_novas_entry(runtime, l2type)
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
    elseif l2type == "VDSL" then
        x:set("network", "vlan_ppp", "ifname", "ptm0")
        x:set("network", "pppv", "ifname", "vlan_ppp")
        x:set("network", "ppp", "ifname", "ptm0")
        x:set("network", "ipoe", "ifname", "ptm0")
    elseif l2type == "ETH" then
        x:set("network", "ppp", "ifname", "eth4")
        x:set("network", "ipoe", "ifname", "eth4")
    end

    x:delete("network", "ppp", "auto")
    x:delete("network", "pppv", "auto")
    x:delete("network", "ipoe", "auto")

    x:commit("network")
    conn:call("network", "reload", { })
    conn:call("network.interface.ppp", "up", { })
    conn:call("network.interface.pppv", "up", { })
    conn:call("network.interface.ipoe", "up", { })

    return true
end

local function novas_entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 entry script is configuring PPP and DHCP on l2type interface " .. tostring(l2type))

    -- setup sensing config on ipoe and ppp interfaces
    local x = uci.cursor()
    local oldifname = x:get("network", "wan", "ifname")
    local device = x:get("network", "vlan_hfc", "ifname")
    local device2 = x:get("network", "vlan_voip", "ifname")

    if l2type == "ADSL" then
        --PPPoE on ADSL 8/35
        x:set("network", "wan", "ifname", "atm_ppp")
        x:delete("network", "wan", "auto")
        x:delete("network", "ppp", "ifname")
        x:set("network", "ppp", "auto", "0")
        x:delete("network", "ipoe", "ifname")
        x:set("network", "ipoe", "auto", "0")
    elseif l2type == "VDSL" then
        -- PPPoE on VLAN2 and IPoE on VLAN6
        if oldifname ~= "vlan_hfc" or device ~= "ptm0" or device2 ~= "ptm0" then
            x:set("network", "wan", "auto", "0")
            x:set("network", "ppp", "auto", "0")
            x:set("network", "vlan_voip", "ifname", "ptm0")
            x:set("network", "vlan_hfc", "ifname", "ptm0")
            x:commit("network")
            conn:call("network", "reload", { })
            x:set("network", "wan", "ifname", "vlan_hfc")
            x:set("network", "wan", "proto", "pppoe")
            x:delete("network", "ppp", "ifname")
        end
        x:delete("network", "wan", "auto")
        x:set("network", "ipoe", "ifname", "vlan_voip")
        x:delete("network", "ipoe", "auto")
    elseif l2type == "ETH" then
        if oldifname ~= "vlan_hfc" or device ~= "eth4" or device2 ~= "eth4" then
            x:set("network", "wan", "auto", "0")
            x:set("network", "ppp", "auto", "0")
            x:set("network", "vlan_voip", "ifname", "eth4")
            x:set("network", "vlan_hfc", "ifname", "eth4")
            x:commit("network")
            conn:call("network", "reload", { })
            x:set("network", "wan", "ifname", "vlan_hfc")
            x:set("network", "wan", "proto", "pppoe")
        end
        x:delete("network", "wan", "auto")
        x:set("network", "ppp", "ifname", "eth4")
        x:delete("network", "ppp", "auto")
        x:set("network", "ipoe", "ifname", "vlan_voip")
        x:delete("network", "ipoe", "auto")
    end
    x:commit("network")
    local old_dnsset = x:get("network", "ipoe", "dnsset")
    if old_dnsset then
        x:delete("network", "ipoe", "dnsset")
        x:commit("network")

        x:delete("dhcp", "voiprule")
        x:delete("dhcp", "cwmprule")
        x:commit("dhcp")

        x:delete("mwan", "voip_only")
        x:commit("mwan")
        os.execute("/etc/init.d/dnsmasq reload")
    end
    local oldcwmpqos = x:get("qos","CWMP","pcp")
    if oldcwmpqos then
        x:delete("qos","CWMP","pcp")
        x:commit("qos")
        os.execute("/etc/init.d/qos restart")
    end
    local oldcwmpinterface = x:get("cwmpd", "cwmpd_config", "interface")
    if oldcwmpinterface ~= "wan" then
        x:set("cwmpd", "cwmpd_config", "interface","wan")
        x:set("mmpbxrvsipnet", "sip_net", "interface", "wan")
        x:commit("cwmpd")
        x:commit("mmpbxrvsipnet")
        os.execute("/etc/init.d/cwmpd reload")
        os.execute("/etc/init.d/mmpbxd reload")
        os.execute("sleep 2")
    end
    conn:call("network", "reload", { })
    conn:call("network.interface.wan", "up", { })
    if l2type ~= "ADSL" then
        conn:call("network.interface.ipoe", "up", { })
        conn:call("network.interface.ppp", "up", { })
    end
    return true
end

function M.entry(runtime, l2type)
    if runtime.variant == "novas" then
        return novas_entry(runtime, l2type)
    else
        return non_novas_entry(runtime, l2type)
    end
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
