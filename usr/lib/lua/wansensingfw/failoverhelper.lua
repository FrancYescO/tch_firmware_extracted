local M = {}
local proxy = require("datamodel")
-- fonState is temp variable stored in /var/state, so new initialize the cursor to manipulate
local cursor = require("uci").cursor(UCI_CONFIG, "/var/state")

-- helper function to set cwmpd interface
local function set_cwmpd_iface(interface, interface6)
    proxy.set("uci.cwmpd.cwmpd_config.interface", interface)
    proxy.set("uci.cwmpd.cwmpd_config.interface6", interface6)
    proxy.apply()
end

-- helper function to get the apn used for a mobile network interface
-- @param x The wansensing uci interface
-- @param intf_name the mobile network interface
-- return mobile APN if available
--        nil if not
local function get_apn(x, intf_name)
    local profile = x:get("network", intf_name, 'profile')
    local apn
    if profile and profile ~= "" then
        x:foreach("mobiled","profile", function(s)
            if s.id == profile then
                apn = s.apn
                return false
            end
        end)
    end
    return apn
end

-- helper function to check if mmpbx is running or not
-- return bool
local function check_voip_running()
    local result = proxy.get("rpc.mmpbx.state")
    local state = result and result[1].value
    if state == "RUNNING" then
        return true
    end
    return false
end

-- helper function to set mmpbxrvsipnet interface
local function set_voip_iface(x, interface, interface6, forced)
    if not forced then
        local apn = get_apn(x, "wwan")
        if apn ~= "telstra.hybrid" then
            return
        end
    end
    x:set("mmpbxrvsipnet", "sip_net", "interface", interface)
    x:set("mmpbxrvsipnet", "sip_net", "interface6", interface6)
    x:commit("mmpbxrvsipnet")
    os.execute("/etc/init.d/mmpbxd restart")
end

-- helper function to retrieve fon param value from /var/state/hotspotd
local function get_fon_state(param)
    local config = "hotspotd"
    cursor:load(config)
    local value = cursor:get(config, "state", param)
    cursor:unload(config)
    return value
end


local function revert_provisioning_code(runtime)
    local uci = runtime.uci
    local x = uci.cursor()
    local default_pcode = x:get("env", "var", "_provisioning_code")
    local curr_pcode = x:get("env", "var", "provisioning_code")
    local scripthelpers = runtime.scripth

    if default_pcode ~= curr_pcode then
        x:set("env", "var", "provisioning_code", default_pcode)
        x:commit("env")
    end
end

--- Helper function to enbled/disable mobile interface
-- @param runtime The wansening context
-- @param enabled 1 or 0
-- @param mobileiface network interface for mobile
function M.mobiled_enable(runtime, enabled, mobileiface)
    local uci = runtime.uci
    local x = uci.cursor()
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth
    local mobileiface_enabled = x:get("network", mobileiface, "enabled")
    local network_changed, mobiled_changed = false, false
    if enabled ~= mobileiface_enabled then
        x:set("network", mobileiface, "enabled", enabled)
        x:commit("network")
        conn:call("network", "reload", { })
        network_changed = true
    end

    if enabled == "1" then
        x:foreach("mobiled", "device", function(s)
            if s["enabled"] ~= enabled then
                x:set("mobiled", s[".name"], "enabled", enabled)
                mobiled_changed = true
            end
        end)

        if mobiled_changed then
            x:commit("mobiled")
            os.execute("/etc/init.d/mobiled reload")
        end
    end
    -- wait for mobile interface to come up or go down
    if network_changed or mobiled_changed then
        local enabled_string = (enabled == "1" and "enabling" or "disabling")
        logger:notice("failover script is " .. enabled_string .. " mobile interface " .. mobileiface)
        os.execute("sleep 3")
    end

    local mobileifaceIsUp = scripthelpers.checkIfInterfaceIsUp(mobileiface)
    mobileifaceIsUp = mobileifaceIsUp and "1" or "0"

    local cwmpdiface = x:get("cwmpd", "cwmpd_config", "interface")
    local voipiface = x:get("mmpbxrvsipnet", "sip_net", "interface")
    local voiceOnFailover = x:get("wansensing", "global", "voiceonfailover")
    local mobileiface4 = mobileiface .. "_4"
    local mobileiface6 = mobileiface .. "_6"
    if enabled == "1" then
        -- disable FON
        local fonstate = get_fon_state("deploy")
        if fonstate == "true" then
--            os.execute("uci -P /var/state set hotspotd.state.deploy='false';/etc/init.d/hotspotd reload")
        end

        -- TR069 over mobile
        if cwmpdiface ~= mobileiface4 and mobileifaceIsUp == "1" then
            x:set("cwmpd", "cwmpd_config", "ip_preference", "v6_only")
            x:commit("cwmpd")
            set_cwmpd_iface(mobileiface4, mobileiface6)
        end

        -- voip over mobile
        if voiceOnFailover == "1" and voipiface ~= mobileiface4 and mobileifaceIsUp == "1" and check_voip_running() then
            set_voip_iface(x, mobileiface4, mobileiface6)
        end
    else
        -- restore fon
        local fonstate = get_fon_state("deploy")
        if fonstate ~= "true" then
            local origstate = get_fon_state("_orig_deploy")
            if origstate == "true" then
--                os.execute("uci -P /var/state set hotspotd.state.deploy='true';/etc/init.d/hotspotd reload")
            end
        end

        -- TR069 over fixed network
        if cwmpdiface == mobileiface4 and mobileifaceIsUp ~= "1" then
            x:set("cwmpd", "cwmpd_config", "ip_preference", "v4_only")
            x:commit("cwmpd")
            set_cwmpd_iface("wan", "wan6")
        end

        -- voip over fixed network
        if voipiface == mobileiface4 and mobileifaceIsUp ~= "1" and check_voip_running() then
            set_voip_iface(x, "wan", "wan6", true)
        end
    end
end

M.revert_provisioning_code = revert_provisioning_code

return M
