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
        x:set("network", "ppp", "ifname", "atm_8_35")
        x:set("network", "ipoe", "ifname", "atm_8_35")
    elseif l2type == "VDSL" then
        x:set("network", "ppp", "ifname", "ptm0")
        x:set("network", "ipoe", "ifname", "ptm0")
    elseif l2type == "ETH" then
        x:set("network", "ppp", "ifname", "eth4")
        x:set("network", "ipoe", "ifname", "eth4")
    end

    x:delete("network", "ppp", "auto")
    x:delete("network", "ipoe", "auto")

    x:commit("network")
    conn:call("network", "reload", { })
    conn:call("network.interface.ppp", "up", { })
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

    logger:notice("The L3 exit script is using transition " .. transition .. " using l2type " .. tostring(l2type))

    return true
end

return M
