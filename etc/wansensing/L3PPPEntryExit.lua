local M = {}

function M.entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3PPP entry script is configuring PPP on wan interface on l2type interface " .. tostring(l2type))

    -- copy ppp sense interfaces to wan interface
    local x = uci.cursor()

    --Check if ppp exists than it is the first time that we enter this state.
    local proto=x:get("network", "wan", "proto") 
    local ifname=x:get("network", "wan", "ifname")
    if not ifname or proto ~= 'pppoe' then
        
	x:set("network", "ppp", "auto", "0")
	x:commit("network")
	conn:call("network", "reload", { })

	scripthelpers.delete_interface("wan")
        scripthelpers.copy_interface("ppp", "wan")
        
	x:delete("network", "ppp", "ifname")
        x:set("network", "wan", "auto", "1")
        x:commit("network")

        --the WAN interface is defined --> create the xtm queues
        if l2type == 'ADSL' or l2type == 'VDSL' then
           os.execute("/etc/init.d/xtm restart")
        end

		os.execute("sleep 2")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
    end

    -- disable 3G/4G
    x:set("mobiledongle", "config", "enabled", "0")
    x:commit("mobiledongle")
    os.execute("/etc/init.d/mobiledongle reload")

    return true
end

function M.exit(runtime,l2type, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3PPP exit script is using transition " .. transition .. " using l2type " .. tostring(l2type))

    -- remove ppp sense interface
    local x = uci.cursor()

    return true
end

return M
