local M = {}

local function non_novas_entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    local interfaces = {
        ADSL = "atm_ipoe",
        VDSL = "ptm0",
        ETH = "eth4"
    }

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3DHCP entry script is configuring DHCP on wan interface on l2type interface " .. tostring(l2type))

    -- initialize failure counters
    runtime.l3dhcp_failures = 0
    runtime.l3rx_bytes =  0
    runtime.l3rxbyte_failures =  0
    -- copy ipoe sense interfaces to wan interface
    local x = uci.cursor()

    --Check if ipoe exists than it is the first time that we enter this state.
    local proto=x:get("network", "wan", "proto")
    local ifname=x:get("network", "wan", "ifname")
    if not ifname or ifname ~= interfaces[l2type] or proto ~= 'dhcp' then
        x:set("network", "ipoe", "auto", "0")
        x:commit("network")
        conn:call("network", "reload", { })
        scripthelpers.delete_interface("wan")
        scripthelpers.copy_interface("ipoe", "wan")
        x:commit("network")
        x:delete("network", "ipoe", "ifname")
        x:set("network", "wan", "ifname", interfaces[l2type])
        x:set("network", "wan", "ipv6", '1')
        x:delete("network", "wan", "auto")
        x:commit("network")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
    end

    -- Set Pbit value for voice to 0
    x:delete("qos","Voice","pcp")
    x:commit("qos")
    os.execute("/etc/init.d/qos restart")
    if l2type == "ADSL" then
        -- connect ppp
        x:set("network", "ppp", "ifname", "atm_ppp")
        x:delete("network", "ppp", "auto")
        -- disconnect pppv
        x:delete("network", "pppv", "ifname")
        x:set("network", "pppv", "auto", "0")
        x:commit("network")
        --the WAN interface is defined --> create the xtm queues
        os.execute("/etc/init.d/xtm restart")
        os.execute("sleep 2")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
        conn:call("network.interface.ppp", "up", { })
    elseif l2type == "VDSL" then
        -- connect ppp
        x:set("network", "ppp", "ifname", "ptm0")
        x:delete("network", "ppp", "auto")
        -- connect pppv
        x:set("network", "pppv", "ifname", "vlan_ppp")
        x:delete("network", "pppv", "auto")
        x:set("network", "vlan_ppp", "ifname", "ptm0")
        x:commit("network")
        --the WAN interface is defined --> create the xtm queues
        os.execute("/etc/init.d/xtm restart")
        os.execute("sleep 2")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
        conn:call("network.interface.ppp", "up", { })
        conn:call("network.interface.pppv", "up", { })
    elseif l2type == "ETH" then
        -- connect ppp
        x:set("network", "ppp", "ifname", "eth4")
        x:delete("network", "ppp", "auto")
        -- connect hfc
        x:set("network", "pppv", "ifname", "vlan_hfc")
        x:delete("network", "pppv", "auto")
        x:set("network", "vlan_hfc", "ifname", "eth4")
        x:commit("network")
        os.execute("sleep 2")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
        conn:call("network.interface.ppp", "up", { })
        conn:call("network.interface.pppv", "up", { })
    end

    return true
end

local function novas_entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3DHCP entry script is configuring DHCP on wan interface on l2type interface " .. tostring(l2type))

    local x = uci.cursor()

    x:delete("network", "ppp", "ifname")
    x:set("network", "ppp", "auto", "0")

    x:set("network", "ipoe", "dnsset", "voipdns")
    x:commit("network")
    conn:call("network", "reload", { })
	x:set("qos","CWMP","pcp","5")

    local domainVoip = x:get("mmpbxrvsipnet", "sip_net", "primary_proxy")
    local domainCwmp = x:get("cwmpd", "cwmpd_config", "acs_url")
    domainCwmp = string.match(domainCwmp, "//(.*):%d")
    x:set("dhcp", "voiprule", "dnsrule")
    x:set("dhcp", "voiprule", "dnsset", "voipdns")
    x:set("dhcp", "voiprule", "domain", domainVoip)
    x:set("dhcp", "voiprule", "outpolicy", "voip_only")

    x:set("dhcp", "cwmprule", "dnsrule")
    x:set("dhcp", "cwmprule", "dnsset", "voipdns")
    x:set("dhcp", "cwmprule", "domain", domainCwmp)
    x:set("dhcp", "cwmprule", "outpolicy", "voip_only")

    x:commit("dhcp")

    x:set("mwan", "voip_only", "policy")
    x:set("mwan", "voip_only", "interface", "ipoe")
    x:commit("mwan")

    os.execute("/etc/init.d/dnsmasq reload")
    os.execute("/etc/init.d/mwan reload")

    x:set("cwmpd", "cwmpd_config", "interface","ipoe")
    x:set("mmpbxrvsipnet", "sip_net", "interface", "ipoe")
    x:commit("qos")
    x:commit("cwmpd")
    x:commit("mmpbxrvsipnet")
    os.execute("/etc/init.d/qos restart")
    os.execute("/etc/init.d/cwmpd reload")
    os.execute("/etc/init.d/mmpbxd reload")
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

    if runtime.variant == "novas" then
        local x = uci.cursor()
        x:delete("network", "ipoe", "dnsset")
        x:commit("network")

        x:delete("dhcp", "voiprule")
        x:delete("dhcp", "cwmprule")
        x:commit("dhcp")

        x:delete("mwan", "voip_only")
        x:commit("mwan")
    end

    logger:notice("The L3DHCP exit script is using transition " .. transition .. " using l2type " .. tostring(l2type))

    return true
end

return M
