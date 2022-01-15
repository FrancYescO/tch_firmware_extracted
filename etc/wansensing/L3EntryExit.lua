local M = {}

function M.entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 entry script is configuring PPP on l2type interface " .. tostring(l2type))

    -- setup sensing config on ipoe and ppp interfaces
    local x = uci.cursor()

    local type=x:get("network", "wan", "type")
    -- In bridge mode, we disabled wansensing. But it may come here when the disabling is in progress.
    if type == "bridge" then
       return false
    end

    local username=x:get("network", "wan", "username")
    local password=x:get("network", "wan", "password")
    local keepalive=x:get("network", "wan", "keepalive")
    local pppoe_backoff=x:get("network", "wan", "pppoe_backoff")
    if l2type == "ADSL" then
	x:set("network", "wan", "auto", "0")
        x:set("network", "ppp_8_35", "username", username)
        x:set("network", "ppp_8_35", "password", password)
        x:set("network", "ppp_8_35", "proto", "pppoe")
        x:set("network", "ppp_8_35", "auto", "1")

        x:set("network", "ppp_8_81", "username", username)
        x:set("network", "ppp_8_81", "password", password)
        x:set("network", "ppp_8_81", "proto", "pppoe")
        x:set("network", "ppp_8_81", "auto", "1")

        if keepalive then
            x:set("network", "ppp_8_35", "keepalive", keepalive)
            x:set("network", "ppp_8_81", "keepalive", keepalive)
        end
        if pppoe_backoff then
            x:set("network", "ppp_8_35", "pppoe_backoff", pppoe_backoff)
            x:set("network", "ppp_8_81", "pppoe_backoff", pppoe_backoff)
        end

        --clear wan configuration
        x:delete("network", "wan", "ifname")

        x:commit("network")

        conn:call("network", "reload", { })
    elseif l2type == "VDSL" then
        x:set("network", "wan", "proto", "pppoe")
        x:set("network", "wan", "ifname", "ptm0_v881")
        x:set("network", "wan", "auto", "1")

        x:commit("network")

        conn:call("network", "reload", { })

    elseif l2type == "ETH" then
        x:set("network", "wan", "proto", "pppoe")
        x:set("network", "wan", "ifname", "eth4_v881")
        x:set("network", "wan", "auto", "1")

        x:commit("network")
        conn:call("network", "reload", { })
    end

    --logger:notice("The L3 entry script is end!")

    return true
end

function M.exit(runtime,l2type, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    return true
end

return M
