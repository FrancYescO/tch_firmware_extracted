---
-- Module L3 EntryExit.
-- Module Specifies the entry and exit functions of a L3 wansensing state
-- @module modulename
local M = {}
local match = string.match

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
    elseif l2type == "VDSL" then
        x:set("network", tostring(interface), "ifname", "ptm0")
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
        setVirtualIPConfig(runtime, l2type, "mgmt")
        logger:notice("Fastweb VirtualIP Scenario: the L3 entry script is end!")
        return true
    end

    -- After provisioning, wan ifname will be update in sts
    local iface = x:get("cwmpd", "cwmpd_config", "interface")
    if iface and match(iface, "^mgmt") then
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
        x:set("ethernet", "globals", "eth4lanwanmode", "1")
        x:commit("ethernet")
        os.execute("/etc/init.d/ethernet reload")
    elseif l2type == "ETH" or l2type == "FIBER" then  --ETH scenario eth4lanwanmode keep as 0
        x:set("network", "wan", "ifname", "eth4")
        x:set("network", "wan", "auto", "1")
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
