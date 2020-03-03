local M = {}
local proxy = require("datamodel")

local key = ("%03d"):rep(2)
local fd = assert(io.open("/dev/urandom", "r"))
local bytes = fd:read(2)
local seed = key:format(bytes:byte(1,2))
math.randomseed(seed)

-- helper function to set cwmpd interface
local function set_cwmpd_iface(interface, interface6)
    proxy.set("uci.cwmpd.cwmpd_config.interface", interface)
    proxy.set("uci.cwmpd.cwmpd_config.interface6", interface6)
    proxy.apply()
end

-- helper function to set remote access interface
local function set_ra_iface(x, interface)
    x:set("web", "remote", "interface", interface)
    x:commit("web")
    os.execute("wget http://127.0.0.1:55555/ra?remote=reload_interface -O-")
end

-- helper function to set ddns interface
local function set_ddns_iface(interface)
    proxy.set("uci.ddns.service.@myddns_ipv4.interface", interface)
    proxy.set("uci.ddns.service.@myddns_ipv4.ip_network", interface)
    proxy.apply()
end

-- helper function to set upnpd interface
local function set_upnpd_iface(interface)
    proxy.set("uci.upnpd.config.external_iface", interface)
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

local function mobiled_timer(runtime, enabled, mobileiface)
    local uci = runtime.uci
    local x = uci.cursor()
    local conn = runtime.ubus
    local logger = runtime.logger

    local autofailovermaxwait = x:get("wansensing", "global", "autofailovermaxwait")
    autofailovermaxwait = tonumber(autofailovermaxwait) or 10
    local random_delay = math.random(1, autofailovermaxwait * 1000)

    local timer = runtime.uloop.timer(function()
        runtime.mobiled_timer = nil
        local autofailover = x:get("wansensing", "global", "autofailover")
        if autofailover == "1" or ((autofailover == "0" or autofailover == "readonly") and enabled == "0") then
            logger:notice("mass failover protection, mobiled timer is timeout, interface '" .. mobileiface .."' " .. (enabled == "1" and "ifup" or "ifdown"))
            if enabled == "1" then
                local mobiled_changed = false
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

            x:set("network", mobileiface, "enabled", enabled)
            x:commit("network")
            conn:call("network", "reload", { })
        else
            logger:notice("mass failover protection, mobiled timer is timeout, no operation due to autofailover disabled")
        end
    end, random_delay)
    logger:notice("mass failover protection, mobiled timer is set, will wait " .. random_delay / 1000 .. " seconds (random in the range [0," .. autofailovermaxwait .. "]) before interface '" .. mobileiface .."' " .. (enabled == "1" and "ifup" or "ifdown"))

    return timer
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
    local mobiledevice_enabled = ""
    x:foreach("mobiled", "device", function(s)
        if s["enabled"] == "1" then
            mobiledevice_enabled = "1"
        else
            mobiledevice_enabled = "0"
        end
        return false -- break
    end)

    local config
    if enabled == "1" then
        if mobileiface_enabled == "0" or (mobileiface_enabled == "1" and mobiledevice_enabled == "0") then
            config = true
        end
    else
        if mobileiface_enabled == "1" then
            config = true
        end
    end

    if config then
        if not runtime.mobiled_timer then
            runtime.mobiled_timer = mobiled_timer(runtime, enabled, mobileiface)
            runtime.mobiled_enabled = enabled
        else
            if enabled ~= runtime.mobiled_enabled then
                runtime.mobiled_timer:cancel()
                logger:notice("mass failover protection, mobiled timer is canceled, and will be reset")
                runtime.mobiled_timer = mobiled_timer(runtime, enabled, mobileiface)
                runtime.mobiled_enabled = enabled
            end
        end
    else
        if runtime.mobiled_timer then
            runtime.mobiled_timer:cancel()
            runtime.mobiled_timer = nil
            runtime.mobiled_enabled = nil
            logger:notice("mass failover protection, mobiled timer is canceled")
        end
    end

    local mobileifaceIsUp = scripthelpers.checkIfInterfaceIsUp(mobileiface)
    mobileifaceIsUp = mobileifaceIsUp and "1" or "0"

    local cwmpdiface = x:get("cwmpd", "cwmpd_config", "interface")
    local ddnsiface = x:get("ddns", "myddns_ipv4", "interface")
    local upnpdiface = x:get("upnpd", "config", "external_iface")
    local voipiface = x:get("mmpbxrvsipnet", "sip_net", "interface")
    local raiface = x:get("web", "remote", "interface")
    local voiceOnFailover = x:get("wansensing", "global", "voiceonfailover")
    local mobileiface4 = mobileiface .. "_4"
    local mobileiface6 = mobileiface .. "_6"
    if enabled == "1" then

        -- TR069 over mobile
        if cwmpdiface ~= mobileiface4 and mobileifaceIsUp == "1" then
            x:set("cwmpd", "cwmpd_config", "ip_preference", "v6_only")
            x:commit("cwmpd")
            set_cwmpd_iface(mobileiface4, mobileiface6)
        end

        -- ddns over mobile
        if ddnsiface ~= mobileiface4 and mobileifaceIsUp == "1" then
            set_ddns_iface(mobileiface4)
        end

        -- upnpd over mobile
        if upnpdiface ~= mobileiface4 and mobileifaceIsUp == "1" then
            set_upnpd_iface(mobileiface4)
        end

        if raiface ~= mobileiface and mobileifaceIsUp == "1" then
            set_ra_iface(x, mobileiface)
        end

        -- voip over mobile
        if voiceOnFailover == "1" and voipiface ~= mobileiface4 and mobileifaceIsUp == "1" and check_voip_running() then
            set_voip_iface(x, mobileiface4, mobileiface6)
        end

    else
        -- TR069 over fixed network
        if cwmpdiface == mobileiface4 and mobileifaceIsUp ~= "1" then
            x:set("cwmpd", "cwmpd_config", "ip_preference", "v4_only")
            x:commit("cwmpd")
            set_cwmpd_iface("wan", "wan6")
        end

        -- ddns over fixed network
        if ddnsiface == mobileiface4 and mobileifaceIsUp ~= "1" then
            set_ddns_iface("wan")
        end

        -- upnpd over fixed network
        if upnpdiface == mobileiface4 and mobileifaceIsUp ~= "1" then
            set_upnpd_iface("wan")
        end

        if raiface == mobileiface and mobileifaceIsUp ~= "1" then
            set_ra_iface(x, "wan")
        end

        -- voip over fixed network
        if voipiface == mobileiface4 and mobileifaceIsUp ~= "1" and check_voip_running() then
            set_voip_iface(x, "wan", "wan6", true)
        end

    end
end

M.revert_provisioning_code = revert_provisioning_code

return M
