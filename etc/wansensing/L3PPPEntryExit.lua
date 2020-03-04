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

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3PPP entry script is configuring PPP on wan interface on l2type interface " .. tostring(l2type))

    local x = uci.cursor()

    --Check if ppp exists than it is the first time that we enter this state.
    local proto=x:get("network", "wan", "proto")
    local ifname=x:get("network", "wan", "ifname")
    if not ifname or ifname ~= interfaces[l2type] or proto ~= 'pppoe' then
        -- initialize failures counter
        runtime.l3ppp_failures = 0
        -- copy ppp sense interfaces to wan interface

        x:set("network", "ppp", "auto", "0")
        x:set("network", "pppv", "auto", "0")
        x:commit("network")
        conn:call("network", "reload", { })

        scripthelpers.delete_interface("wan")
        scripthelpers.copy_interface("ppp", "wan")
        x:commit("network")
        x:delete("network", "wan", "auto")
        x:set("network", "wan", "ipv6", '1')
        x:commit("network")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
    end
    x:set("network", "ppp", "auto", "0")
    -- disconnect ipoe and put on different interface according to product spec
    x:set("network", "ipoe", "auto", "0")
    -- disconnect pppv and put on different interface
    x:set("network", "pppv", "auto", "0")
    x:commit("network")
    -- Set Pbit value for voice to 0
    x:delete("qos","Voice","pcp")
    x:commit("qos")
    os.execute("/etc/init.d/qos restart")
    if l2type == "ADSL" then
        --the WAN interface is defined --> create the xtm queues
        os.execute("/etc/init.d/xtm restart")
        os.execute("sleep 2")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
    elseif l2type == "VDSL" then
        --the WAN interface is defined --> create the xtm queues
        os.execute("/etc/init.d/xtm restart")
        os.execute("sleep 2")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
    elseif l2type == "ETH" then
        os.execute("sleep 2")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
    end
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
    x:delete("network", "ipoe", "ifname")
    x:set("network", "ipoe", "auto", "0")
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
