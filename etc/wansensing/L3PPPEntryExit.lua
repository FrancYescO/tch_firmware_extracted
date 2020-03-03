local M = {}
local failoverhelper = require('wansensingfw.failoverhelper')

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
        failoverhelper.revert_provisioning_code(runtime)

        x:set("network", "ppp", "auto", "0")
        x:commit("network")
        conn:call("network", "reload", { })

	    if l2type == "ADSL" then
	        x:set("network", "ipoe", "ifname", "atm_8_35")
	    elseif l2type == "VDSL" then
	        x:set("network", "ipoe", "ifname", "ptm0")
	    elseif l2type == "ETH" then
	        x:set("network", "ipoe", "ifname", "eth4")
	    end

        scripthelpers.delete_interface("wan")
        scripthelpers.copy_interface("ppp", "wan")
        x:set("network", "wan6", "ifname", "@wan")

        x:delete("network", "ppp", "ifname")
        x:commit("network")
        conn:call("network", "reload", { })

        --the WAN interface is defined --> create the xtm queues
        os.execute("sleep 1")
        if l2type == 'ADSL' or l2type == 'VDSL' then
           os.execute("/etc/init.d/ethoam stop")
           os.execute("/etc/init.d/xtm reload")
        end

        x:set("network", "ipoe", "auto", "1")
        x:set("network", "wan6", "auto", "1")
        x:set("network", "wan", "auto", "1")
        x:commit("network")

        os.execute("sleep 1")
        conn:call("network", "reload", { })
        conn:call("network.interface.wan", "up", { })
        conn:call("network.interface.wan6", "up", { })

        if l2type == 'VDSL' then
           os.execute("/etc/init.d/ethoam reload")
        end
    end

    os.execute("test -f /usr/bin/queue-resize.sh && sh /usr/bin/queue-resize.sh")

    runtime.l3ppp_failures = 0
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
