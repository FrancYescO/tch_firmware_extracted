---
-- Module L3 EntryExit.
-- Module Specifies the entry and exit functions of a L3 wansensing state
-- @module modulename
local M = {}
local match = string.match
local process = require("tch.process")

local function setVirtualIPConfig(runtime, l2type, interface)
    local uci = runtime.uci
    local conn = runtime.ubus
    local x = uci.cursor()
    local logger = runtime.logger

    logger:notice("Fastweb VirtualIP Scenario : reconfigure the network stack")
    if l2type == "ADSL" then
        x:set("network", tostring(interface), "ifname", "atm0")
        x:delete("network", tostring(interface), "auto")
        x:commit("network")
        -- xtm transmission topology
        os.execute("/etc/init.d/xtm reload")
        conn:call("network", "reload", { })
    elseif l2type == "ETH" or l2type == "FIBER" then
        x:set("network", tostring(interface), "ifname", "eth4")
        x:delete("network", tostring(interface), "auto")
        x:commit("network")
        conn:call("network", "reload", { })
    end
end

local function MigrateAdsl2IP(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local x = uci.cursor()
    local logger = runtime.logger

    logger:notice("Fastweb migrate ADSL 2PVC/loopback scenario to VDSL : reconfigure the network stack")
    if l2type == "VDSL" then
        logger:notice("Activate untagged VDSL Interface in DHCP-Mode: use Management Interface")
        x:set("network", "mgmt", "ifname", "ptm0")
        x:set("network", "mgmt", "auto", "1")

        logger:notice("Activate dummy VDSL Interface in DHCP-Mode:")
        x:set("network", "wantag", "ifname", "@vlan_wan")
        x:set("network", "wantag", "auto", "1")
    elseif l2type == "ADSL" then
        logger:notice("Switch back to ADSL 2PVC/loopback by Operator, if Migration has problems")
        local iface = x:get("cwmpd", "cwmpd_config", "interface")
        -- possible values CWMPD-Interface: wan; mgmt
        if iface == "mgmt" then
            logger:notice("Activate ADSL Management Interface again")
            x:set("network", "mgmt", "ifname", "atm0")

            logger:notice("Disable Dummy VDSL Interface in DHCP-Mode:")
            x:delete("network", "wantag", "ifname")
            x:set("network", "wantag", "auto", "0")
        end
    end

    logger:notice("apply network settings via reload")
    x:commit("network")
    conn:call("network", "reload", { })
end

---
-- Entry function called if a wansensing L3 state is entered.
--
-- @function [parent=M]
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @return #1 boolean indicates if the entry actions are executed/not executed
function M.entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 entry script is configuring WAN on l2type interface " .. tostring(l2type))

    runtime.entry_l3 = true
    local x = uci.cursor()
    --After provisioning to loopback scenario, wan ifname will be @mgmt
    local ifname = x:get("network", "wan", "ifname")
    if ifname and match(ifname, "^@mgmt") then
        local ifnamemgmt = x:get("network", "mgmt", "ifname")
        if l2type == "VDSL" and ifnamemgmt == "atm0" then
            logger:notice("Fastweb VirtualIP Scenario migrated from ADSL loopback to VDSL: ")
            MigrateAdsl2IP(runtime, l2type)
            logger:notice("Fastweb VirtualIP Scenario: the L3 entry script is end!")
            return true
        elseif l2type == "ADSL" and ifnamemgmt ~= "atm0" then
            logger:notice("Fastweb VirtualIP Scenario fallback from VDSL test to ADSL loopback: ")
            MigrateAdsl2IP(runtime, l2type)
            logger:notice("Fastweb VirtualIP Scenario: the L3 entry script is end!")
            return true
        end
        setVirtualIPConfig(runtime, l2type, "mgmt")
        logger:notice("Fastweb VirtualIP Scenario: the L3 entry script is end!")
        return true
    end

    -- After provisioning, wan ifname will be update in sts
    local iface = x:get("cwmpd", "cwmpd_config", "interface")
    if iface and match(iface, "^mgmt") then
        if l2type == "VDSL" then
            -- for migration from 2PVC to VDSL
            MigrateAdsl2IP(runtime, l2type)
        elseif l2type == "ADSL" then
            local ifnamemgmt =  x:get("network", "mgmt", "ifname")
            if ifnamemgmt ~= "atm0" then
                -- fallback from VDSL test to ADSL
                MigrateAdsl2IP(runtime, l2type)
            end
        end

        logger:notice("Fastweb 2PVC Scenario: the L3 entry script is end!")
        return true
    end

    --Before Provisioning need set wan up in following scenario:
    if l2type == "ADSL" then
        x:set("network", "wan", "ifname", "atm0")
        x:set("network", "wan", "auto", "1")
        x:set("network", "wantag", "ifname", "atm1")
        x:set("network", "wantag", "auto", "1")
        x:set("ethernet", "globals", "eth4lanwanmode", "1")
        x:commit("ethernet")
        os.execute("/etc/init.d/ethernet reload")
    elseif l2type == "VDSL" then
        x:set("network", "wan", "ifname", "ptm0")
        x:set("network", "wan", "auto", "1")
        x:set("network", "wantag", "ifname", "@vlan_wan")
        x:set("network", "wantag", "auto", "1")

        logger:notice("L3EntryExit::entry: change Management and Voice pcp to 2 for VDSL tag")
        x:set("qos", "Management", "pcp", 2)
        x:set("qos", "Voice_Data", "pcp", 2)
        x:set("qos", "Voice_Sig", "pcp", 2)
        x:commit("qos")
        process.execute("/etc/init.d/qos", {"reload"})

        x:set("ethernet", "globals", "eth4lanwanmode", "1")
        x:commit("ethernet")
        os.execute("/etc/init.d/ethernet reload")
    elseif l2type == "ETH" or l2type == "FIBER" then  --ETH scenario eth4lanwanmode keep as 0
        x:set("network", "wan", "ifname", "eth4")
        x:set("network", "wan", "auto", "1")
        if l2type == "ETH" then
            x:set("network", "wantag", "ifname", "@vlan_wan_eth4")
            x:set("network", "wantag", "auto", "1")
            logger:notice("L3Main::setWanConfig: change Management and Voice pcp to 1 in vlan_eth4 tag")
            x:set("qos", "Management", "pcp", 1)
            x:set("qos", "Voice_Data", "pcp", 1)
            x:set("qos", "Voice_Sig", "pcp", 1)
            x:commit("qos")
            process.execute("/etc/init.d/qos", {"reload"})
        end
    end

    logger:notice("apply network settings via reload")
    x:commit("network")
    conn:call("network", "reload", { })

    logger:notice("The L3 entry script is end!")
    return true
end

---
-- Exit function called if a wansensing L3 state is exited.
--
-- @function [parent=M]
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @param #3 string specifying the next state
-- @return #1 boolean indicates if the exit actions are executed/not executed
function M.exit(runtime, l2type, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 exit script is end!")
    return true
end

return M
