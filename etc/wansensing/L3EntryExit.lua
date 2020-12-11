local M = {}

function M.entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 entry script is configuring PPP/DHCP on l2type interface " .. tostring(l2type))

    local x = uci.cursor()

    local eth_mac = x:get("env", "rip", "eth_mac")
    local mac = string.gsub(eth_mac, ":+", "")
    local ppp_user = x:get("network", "wan", "username")
    local ppp_pass = x:get("network", "wan", "password")
    if ppp_user==nil then ppp_user = "mruser@unprovision" end
    if ppp_pass==nil then ppp_pass = "dummypass" end

    -- config layer3 interface according to layer2 interface
    if l2type == "ADSL" then
        x:set("xtm", "atm_8_35", "ulp", "ppp")
        x:set("network", "wan", "ifname", "atm_8_35")
        x:set("network", "wan", "proto", "pppoa")
        x:set("network", "wan", "username", ppp_user)
        x:set("network", "wan", "password", ppp_pass)
        x:delete("network", "wan", "dns")
        x:delete("network", "wan", "netmask")
        x:delete("network", "wan", "ipaddr")
        x:delete("network", "wan", "gateway")
        x:delete("network", "wan", "reqopts")
        x:delete("network", "wan", "release")
        x:delete("network", "wan", "vendorid")
        x:delete("network", "wan", "sendopts")
    elseif l2type == "VDSL" then
        x:set("network", "wan", "ifname", "vlan_ptc274")
        x:set("network", "wan", "proto", "dhcp")
        x:set("network", "wan", "reqopts", "1 3 6 15 33 42 43 51 121 249")
        x:set("network", "wan", "release", "1")
        x:set("network", "wan", "vendorid", "dslforum.org")
        x:set("network", "wan", "sendopts", "61:01"..mac)
        x:delete("network", "wan", "username")
        x:delete("network", "wan", "password")
        x:delete("network", "wan", "dns")
        x:delete("network", "wan", "netmask")
        x:delete("network", "wan", "ipaddr")
        x:delete("network", "wan", "gateway")
    elseif l2type == "ETH" then
        x:set("network", "wan", "ifname", "eth4")
        x:set("network", "wan", "proto", "dhcp")
        x:set("network", "wan", "reqopts", "1 3 6 15 33 42 43 51 121 249")
        x:set("network", "wan", "release", "1")
        x:set("network", "wan", "vendorid", "dslforum.org")
        x:set("network", "wan", "sendopts", "61:01"..mac)
        x:delete("network", "wan", "username")
        x:delete("network", "wan", "password")
        x:delete("network", "wan", "dns")
        x:delete("network", "wan", "netmask")
        x:delete("network", "wan", "ipaddr")
        x:delete("network", "wan", "gateway")
    end

    x:delete("network", "wan", "auto")
    x:commit("xtm")
    x:commit("network")
    --the WAN interface is defined --> create the xtm queues
    if l2type == 'ADSL' or l2type == 'VDSL' then
       os.execute("/etc/init.d/xtm reload")
       os.execute("sleep 2")
    end

    conn:call("network", "reload", { })

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
