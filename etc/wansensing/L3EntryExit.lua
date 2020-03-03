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
    local user = x:get("network", "ppp", "username")

    -- initialize lteback_delay_counter
    runtime.ltebackup_delay_counter = 0

    -- copy ipoe sense interfaces to wan interface
    x:set("network", "ipoe", "auto", "0")
    x:commit("network")
    conn:call("network", "reload", { })

    scripthelpers.delete_interface("wan")
    scripthelpers.copy_interface("ipoe", "wan")
    x:delete("network", "ipoe", "ifname")
    x:commit("network")

    if l2type == "ADSL" then
        x:set("network", "ppp", "ifname", "atm_8_35")
        x:set("network", "wan", "ifname", "atm_8_35")
        x:set("network", "wan6", "ifname", "atm_8_35")
    elseif l2type == "VDSL" then
        x:set("network", "ppp", "ifname", "ptm0")
        x:set("network", "wan", "ifname", "ptm0")
        x:set("network", "wan6", "ifname", "ptm0")
    elseif l2type == "ETH" then
        x:set("network", "ppp", "ifname", "eth4")
        x:set("network", "wan", "ifname", "eth4")
        x:set("network", "wan6", "ifname", "eth4")
    end
    x:commit("network")
    conn:call("network", "reload", { })

    --the WAN interface is defined --> create the xtm queues
    os.execute("sleep 1")
    if l2type == 'ADSL' or l2type == 'VDSL' then
       os.execute("/etc/init.d/ethoam stop")
       os.execute("/etc/init.d/xtm reload")
    end

    if user ~= nil then
       x:delete("network", "ppp", "auto")
    end
    x:delete("network", "wan", "auto")
    x:delete("network", "wan6", "auto")

    x:commit("network")

    os.execute("sleep 1")
    conn:call("network", "reload", { })
    if user ~= nil then
    conn:call("network.interface.ppp", "up", { })
    end
    conn:call("network.interface.wan", "up", { })
    conn:call("network.interface.wan6", "up", { })

    if l2type == 'VDSL' then
       os.execute("/etc/init.d/ethoam reload")
    end

	os.execute("bs /b/c egress_tm/dir=us,index=0 queue_cfg[0]={queue_id=0,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=1 queue_cfg[0]={queue_id=1,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=2 queue_cfg[0]={queue_id=2,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=3 queue_cfg[0]={queue_id=3,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=4 queue_cfg[0]={queue_id=4,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=5 queue_cfg[0]={queue_id=5,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=6 queue_cfg[0]={queue_id=6,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=7 queue_cfg[0]={queue_id=7,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}")
	os.execute("bs /b/c egress_tm/dir=us,index=20 queue_cfg[0]={queue_id=0,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=21 queue_cfg[0]={queue_id=1,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=22 queue_cfg[0]={queue_id=2,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=23 queue_cfg[0]={queue_id=3,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=24 queue_cfg[0]={queue_id=4,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=25 queue_cfg[0]={queue_id=5,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=26 queue_cfg[0]={queue_id=6,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes};bs /b/c egress_tm/dir=us,index=27 queue_cfg[0]={queue_id=7,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}")

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
