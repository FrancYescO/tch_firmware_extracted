local M = {}
local proxy = require("datamodel")
local ipairs, pairs, tonumber = ipairs, pairs, tonumber

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
local function set_ra_iface(x, interface, interface6)
    x:set("web", "remote", "interface", interface)
    x:set("web", "remote", "interface6", interface6)
    x:commit("web")
    os.execute("wget http://127.0.0.1:55555/ra?remote=reload_interface -O-")
end

-- helper function to set ddns interface
local function set_ddns_iface(interface, interface6)
    local ddns_ipv4_path = "uci.ddns.service.@myddns_ipv4."
    local ddns_ipv6_path = "uci.ddns.service.@myddns_ipv6."
    local ddns_ipv4 = proxy.get(ddns_ipv4_path)
    local ddns_ipv6 = proxy.get(ddns_ipv6_path)
    if ddns_ipv4 then
        proxy.set("uci.ddns.service.@myddns_ipv4.interface", interface)
        proxy.set("uci.ddns.service.@myddns_ipv4.ip_network", interface)
    end
    if ddns_ipv6 then
        proxy.set("uci.ddns.service.@myddns_ipv6.interface", interface6)
        proxy.set("uci.ddns.service.@myddns_ipv6.ip_network", interface6)
    end
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

-- helper function to enable/disable wifi_doctor_agent
local function set_wifi_doctor(x, enabled)
    x:set("wifi_doctor_agent", "config", "enabled", enabled)
    x:commit("wifi_doctor_agent")
    os.execute("/etc/init.d/wifi-doctor-agent restart")
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

local function create_random_delay(runtime)
    local uci = runtime.uci
    local x = uci.cursor()
    local autofailovermaxwait = x:get("wansensing", "global", "autofailovermaxwait")
    autofailovermaxwait = tonumber(autofailovermaxwait) or 10
    return math.random(1, autofailovermaxwait * 1000), autofailovermaxwait
end

local function mobiled_timer_cb(runtime, enabled, mobileiface)
    local uci = runtime.uci
    local x = uci.cursor()
    local conn = runtime.ubus
    local logger = runtime.logger
    local random_delay, autofailovermaxwait = create_random_delay(runtime)

    local timer = runtime.uloop.timer(function()
        runtime.mobiled_timer = nil
        local autofailover = x:get("wansensing", "global", "autofailover")
        if autofailover == "1" or (autofailover ~= "1" and enabled == "0") then
            logger:notice("mass failover protection, mobiled data timer is timeout, interface '" .. mobileiface .."' " .. (enabled == "1" and "ifup" or "ifdown"))
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
            logger:notice("mass failover protection, mobiled data timer is timeout, no operation due to autofailover disabled")
        end
    end, random_delay)
    logger:notice("mass failover protection, mobiled data timer is set, will wait " .. random_delay / 1000 .. " seconds (random in the range [0," .. autofailovermaxwait .. "]) before interface '" .. mobileiface .."' " .. (enabled == "1" and "ifup" or "ifdown"))

    return timer
end

local function isVoLTECalling(runtime)
    local uci = runtime.uci
    local x = uci.cursor()
    local conn = runtime.ubus
    local mobilenet_profiles = {}
    x:foreach("mmpbxmobilenet", "profile", function(s)
        if s["enabled"] == "1" then
            mobilenet_profiles[s[".name"]] = true
        end
    end)
    local content = conn:call("mmpbx.call", "get", {})
    if content then
        for _,v in pairs(content) do
            if mobilenet_profiles[v.profile] then
                return true
            end
        end
    end
    return false
end

local function get_mobiled_session(runtime, session_name)
    local uci = runtime.uci
    local x = uci.cursor()
    local session = {}
    x:foreach("mobiled_sessions", "session", function(s)
        if s.name == session_name then
            session.session_id = tonumber(s.session_id)
            session.profile = s.profile
            return false -- break
        end
    end)
    return session
end

local function mobilenet_profile_enabled(runtime)
    local uci = runtime.uci
    local x = uci.cursor()
    local result = false
    x:foreach("mmpbxmobilenet", "profile", function(s)
        if s["enabled"] == "1" then
            result = true
            return false -- break
        end
    end)
    return result
end

local function mobiled_ims_timer_cb(runtime, enabled, ims_session)
    if enabled == "1" then
        return nil
    end
    local uci = runtime.uci
    local x = uci.cursor()
    local conn = runtime.ubus
    local logger = runtime.logger
    local random_delay, autofailovermaxwait = create_random_delay(runtime)

    local timer = runtime.uloop.timer(function()
        if random_delay then
            logger:notice("mass failover protection, mobiled ims timer is timeout, ims pdn session will be deactivated")
            random_delay = nil
        end
        if runtime.mobiled_ims_timer then
            if isVoLTECalling(runtime) then
                -- wait for 5 seconds then check again
                logger:notice("4G voice call is ongoing, mobiled ims timer is reset, will try to deactivate in 5 seconds")
                runtime.mobiled_ims_timer:set(5000)
            else
                -- deactivate IMS PDN
                conn:send("mobiled", {event = "session_deactivate", dev_idx = 1, session_id = ims_session.session_id})
                logger:notice("ubus send mobiled '{\"event\":\"session_deactivate\", \"dev_idx\":1, \"session_id\":" .. ims_session.session_id .. "}'")
                runtime.mobiled_ims_timer:cancel()
                runtime.mobiled_ims_timer = nil
            end
        else
            logger:notice("mass failover protection, mobiled ims timer is canceled")
        end
    end,random_delay)
    logger:notice("mass failover protection, mobiled ims timer is set, will wait " .. random_delay / 1000 .. " seconds (random in the range [0," .. autofailovermaxwait .. "]) before ims pdn session deactivate")

    return timer
end

local function mobiled_ims_timer_cancel(runtime)
    local logger = runtime.logger
    if runtime.mobiled_ims_timer then
        runtime.mobiled_ims_timer:cancel()
        runtime.mobiled_ims_timer = nil
        logger:notice("mass failover protection, mobiled ims timer is canceled")
    end
end

local function reload_cwmpd_timer_cancel(runtime)
    local logger = runtime.logger
    if runtime.reload_cwmpd_timer then
        runtime.reload_cwmpd_timer:cancel()
        runtime.reload_cwmpd_timer = nil
        logger:notice("Reload cwmpd timer is canceled")
    end
end

local function reload_cwmpd_timer_cb(runtime)
    local logger = runtime.logger
    local count = 5
    local fixedifaceIsUp
    local scripthelpers = runtime.scripth
    local timer = runtime.uloop.timer(function()
        logger:notice("reload_cwmpd_timer running count=" .. count)
        if runtime.reload_cwmpd_timer then
            fixedifaceIsUp = scripthelpers.checkIfInterfaceHasIP("wan6", true)
            if count > 0 and not fixedifaceIsUp then
                count = count-1
                runtime.reload_cwmpd_timer:set(3000)
            else
                count = 0
                reload_cwmpd_timer_cancel(runtime)
                os.execute("/etc/init.d/cwmpd reload")
            end
         end
    end,3000)
    return timer
end

local function set_cwmpd_fixed_network_iface(runtime)
    local logger = runtime.logger
    local uci = runtime.uci
    local scripthelpers = runtime.scripth
    local x = uci.cursor()
    local fixedifaceIsUp = scripthelpers.checkIfInterfaceHasIP("wan6", true)
    if not fixedifaceIsUp then
        x:set("cwmpd", "cwmpd_config", "ip_preference", "prefer_v6")
        x:set("cwmpd", "cwmpd_config", "interface", "wan")
        x:set("cwmpd", "cwmpd_config", "interface6", "wan6")
        x:commit("cwmpd")
        reload_cwmpd_timer_cancel(runtime)
        runtime.reload_cwmpd_timer = reload_cwmpd_timer_cb(runtime)
    else
        x:set("cwmpd", "cwmpd_config", "ip_preference", "prefer_v6")
        x:commit("cwmpd")
        set_cwmpd_iface("wan", "wan6")
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
            runtime.mobiled_timer = mobiled_timer_cb(runtime, enabled, mobileiface)
            runtime.mobiled_enabled = enabled
        else
            if enabled ~= runtime.mobiled_enabled then
                runtime.mobiled_timer:cancel()
                logger:notice("mass failover protection, mobiled data timer is canceled, and will be reset")
                runtime.mobiled_timer = mobiled_timer_cb(runtime, enabled, mobileiface)
                runtime.mobiled_enabled = enabled
            end
        end
    else
        if runtime.mobiled_timer then
            runtime.mobiled_timer:cancel()
            runtime.mobiled_timer = nil
            runtime.mobiled_enabled = nil
            logger:notice("mass failover protection, mobiled data timer is canceled")
        end
    end

    local ims_session = get_mobiled_session(runtime, "internal_ims_pdn")
    if ims_session.session_id and ims_session.profile then
        local data = conn:call("mobiled.network", "sessions", {session_id = ims_session.session_id}) or {}
        ims_session.activated = data.activated
        if enabled == "1" then
            mobiled_ims_timer_cancel(runtime)
            if ims_session.activated == false then
                if mobilenet_profile_enabled(runtime) then
                    -- activate IMS PDN without randomised delay as specification required
                    conn:send("mobiled", {event = "session_activate", dev_idx = 1, session_id = ims_session.session_id, profile_id = ims_session.profile})
                    logger:notice("ubus send mobiled '{\"event\":\"session_activate\", \"dev_idx\":1, \"session_id\":" .. ims_session.session_id .. ", \"profile_id\":\"" .. ims_session.profile .. "\"}'")
                end
            end
        else
            if ims_session.activated == true then
                if not runtime.mobiled_ims_timer then
                    runtime.mobiled_ims_timer = mobiled_ims_timer_cb(runtime, enabled, ims_session)
                end
            else
                mobiled_ims_timer_cancel(runtime)
            end
        end
    end

    local mobileifaceIsUp = scripthelpers.checkIfInterfaceIsUp(mobileiface)
    mobileifaceIsUp = mobileifaceIsUp and "1" or "0"
    -- when mobileifaceIsUp is 0, send event mobiled interface is down
    if mobileifaceIsUp ~= "1" then
        conn:send('wwan.state', { status = 'unavailable'})
    end
    local cwmpdiface = x:get("cwmpd", "cwmpd_config", "interface")
    local ddnsiface = x:get("ddns", "myddns_ipv4", "interface")
    local upnpdiface = x:get("upnpd", "config", "external_iface")
    local voipiface = x:get("mmpbxrvsipnet", "sip_net", "interface")
    local raiface = x:get("web", "remote", "interface")
    local voiceOnFailover = x:get("wansensing", "global", "voiceonfailover")
    local wifidoctor = x:get("wifi_doctor_agent", "config", "enabled")
    local wifidoctorurl = x:get("wifi_doctor_agent", "config", "cs_url") or ""
    local mobileiface4 = mobileiface .. "_4"
    local mobileiface6 = mobileiface .. "_6"
    if enabled == "1" then

        -- TR069 over mobile
        if cwmpdiface ~= mobileiface4 and mobileifaceIsUp == "1" then
            reload_cwmpd_timer_cancel(runtime)
            x:set("cwmpd", "cwmpd_config", "ip_preference", "v6_only")
            x:commit("cwmpd")
            set_cwmpd_iface(mobileiface4, mobileiface6)
        end

        -- ddns over mobile
        if ddnsiface ~= mobileiface4 and mobileifaceIsUp == "1" then
            set_ddns_iface(mobileiface4, mobileiface6)
        end

        -- upnpd over mobile
        if upnpdiface ~= mobileiface4 and mobileifaceIsUp == "1" then
            set_upnpd_iface(mobileiface4)
        end

        if raiface ~= mobileiface4 and mobileifaceIsUp == "1" then
            set_ra_iface(x, mobileiface4, mobileiface6)
        end

        -- voip over mobile
        if voiceOnFailover == "1" and voipiface ~= mobileiface4 and mobileifaceIsUp == "1" and check_voip_running() then
            set_voip_iface(x, mobileiface4, mobileiface6)
        end

        -- disable wifi-doctor
        if wifidoctor == "1" and mobileifaceIsUp == "1" then
            set_wifi_doctor(x, "0")
        end
    else
        -- TR069 over fixed network
        if cwmpdiface == mobileiface4 and mobileifaceIsUp ~= "1" then
            set_cwmpd_fixed_network_iface(runtime)
        end

        -- ddns over fixed network
        if ddnsiface == mobileiface4 and mobileifaceIsUp ~= "1" then
            set_ddns_iface("wan", "wan6")
        end

        -- upnpd over fixed network
        if upnpdiface == mobileiface4 and mobileifaceIsUp ~= "1" then
            set_upnpd_iface("wan")
        end

        if raiface == mobileiface4 and mobileifaceIsUp ~= "1" then
            set_ra_iface(x, "wan", "wan6")
        end

        -- voip over fixed network
        if voipiface == mobileiface4 and mobileifaceIsUp ~= "1" and check_voip_running() then
            set_voip_iface(x, "wan", "wan6", true)
        end

        if wifidoctor == "0" and wifidoctorurl ~= "" and mobileifaceIsUp ~= "1" then
            -- enable wifi-doctor
            set_wifi_doctor(x, "1")
        elseif wifidoctor == "1" and wifidoctorurl == "" then
            -- disable wifi-doctor if wifi doctor url is blank
            set_wifi_doctor(x, "0")
        end
    end
end

M.revert_provisioning_code = revert_provisioning_code

return M
