local M = {}

local function non_novas_entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    local interfaces = {
        ADSL = "atm_ppp",
        VDSL = "ptm0",
        ETH = "eth4"
    }

    local vlaninterfaces = {
        ADSL = "vlan_ppp",
        VDSL = "vlan_ppp",
        ETH = "vlan_hfc"
    }

    local notvlaninterfaces = {
        ADSL = "vlan_hfc",
        VDSL = "vlan_hfc",
        ETH = "vlan_ppp"
    }

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3PPPV entry script is configuring PPP VLAN on wan interface on l2type interface " .. tostring(l2type))

    local x = uci.cursor()

    --Check if ppp exists than it is the first time that we enter this state.
    local proto=x:get("network", "wan", "proto")
    local ifname=x:get("network", "wan", "ifname")
    local vlanifname=x:get("network", vlaninterfaces[l2type], "ifname")
    if not ifname or ifname ~= vlaninterfaces[l2type] or vlanifname ~= interfaces[l2type] or proto ~= 'pppoe' then
        -- initialize failures counter
        runtime.l3ppp_failures = 0
        -- copy pppv sense interfaces to wan interface

        x:set("network", "ppp", "auto", "0")
        x:set("network", "pppv", "auto", "0")
        x:commit("network")
        conn:call("network", "reload", { })

        scripthelpers.delete_interface("wan")
        scripthelpers.copy_interface("pppv", "wan")
        x:commit("network")
        x:delete("network", "wan", "auto")
        x:set("network", "wan", "ipv6", '1')
        x:commit("network")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
    end
    x:set("network", "pppv", "auto", "0")
    x:set("network", vlaninterfaces[l2type], "ifname", interfaces[l2type])
    -- disconnect ipoe and put on different interface according to product spec
    x:set("network", "ipoe", "auto", "0")
    -- disconnect ppp and put on different interface
    x:set("network", "ppp", "auto", "0")
    if l2type == "ADSL" then
        -- Set Pbit value for voice to 0
        x:delete("qos","Voice","pcp")
    elseif l2type == "VDSL" then
        -- Set Pbit value for voice to 5
        x:set("qos","Voice","pcp","5")
    elseif l2type == "ETH" then
        -- Set Pbit value for voice to 0
        x:delete("qos","Voice","pcp")
    end

    x:commit("network")
    x:commit("qos")
    os.execute("/etc/init.d/qos restart")

    --the WAN interface is defined --> create the xtm queues
    if l2type == 'ADSL' or l2type == 'VDSL' then
       os.execute("/etc/init.d/xtm restart")
    end

    os.execute("sleep 2")
    conn:call("network", "reload", { })
    conn:call("network.interface.wan", "up", { })
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

    x:delete("network", "ppp", "ifname")
    x:set("network", "ppp", "auto", "0")
    x:commit("network")
    conn:call("network", "reload", { })
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

    logger:notice("The L3PPP exit script is using transition " .. transition .. " using l2type " .. tostring(l2type))

    runtime.l3ppp_failures = 0
    return true
end

return M
