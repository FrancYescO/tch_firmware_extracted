local M = {}

function M.mobiled_enable(runtime, enabled)
    local uci = runtime.uci
    local x = uci.cursor()
    local conn = runtime.ubus
    local scripthelpers = runtime.scripth
    local mobiled_network_intf = "wwan"

    local mobileiface_enabled = x:get("network", mobiled_network_intf, "enabled") == "" and "1"
    local mobileiface_auto = x:get("network", mobiled_network_intf, "auto") == "" and "1"

    if enabled == "1" and mobileiface_enabled == "1" and mobileiface_auto == "1" then
        return
    end

    if enabled == "0" and mobileiface_enabled == "0" and mobileiface_auto == "0" then
        return
    end

    x:set("network", mobiled_network_intf, "auto", enabled)
    x:set("network", mobiled_network_intf, "enabled", enabled)
    x:commit("network")
    conn:call("network", "reload", {})
end

function M.tod_config(runtime, enabled)
    local uci = runtime.uci
    local x = uci.cursor()
    local tod_changed = false
    local backup_enabled = x:get("tod", "mobiled_backup", "enabled")
    local old_scheduled = x:get("tod", "mobiled_backup", "object")
    local scheduled = x:get("wansensing", "global", "backup_time") or "60"

    if (backup_enabled ~= '1' or old_scheduled ~= scheduled) and enabled == '1' then
        local genabled = x:get("tod", "global", "enabled")
        local time = os.time() + scheduled * 60
        local starttime = os.date("%a", time) .. ":" .. os.date("%X", time)

        if genabled == "0" then
            x:set("tod", "global", "enabled", "1")
        end
        tod_changed = true
        if backup_enabled == nil then
            x:set("tod", "mobiled_backup", "action")
            x:set("tod", "mobiled_backup", "script", "mobiledtodscript")
            x:set("tod", "mobiled_disable_timer", "timer")
        end
        local timer_list = {"mobiled_disable_timer"}
        x:set("tod", "mobiled_backup", "enabled", "1")
        x:set("tod", "mobiled_backup", "timers", timer_list)
        x:set("tod", "mobiled_backup", "object", scheduled)
        x:set("tod", "mobiled_disable_timer", "start_time", starttime)
    elseif backup_enabled == '1' and enabled == '0' then
        tod_changed = true
        x:set("tod", "mobiled_backup", "enabled", "0")
    end
    if tod_changed then
        x:commit("tod")
        os.execute("/etc/init.d/tod restart")
    end
end

local mode_handler = {
    auto = function(runtime, cursor, wan_if, wan_auto)
        if wan_auto == "0" then
            cursor:set("network", wan_if, "auto", "1")
            return true
        end
        return false
    end,
    Fixed_line = function(runtime, cursor, wan_if, wan_auto)
        local netchanged = false
        if wan_auto == "0" then
            cursor:set("network", wan_if, "auto", "1")
            netchanged = true
        end
        -- disable 3G/4G
        M.mobiled_enable(runtime, "0")
        return netchanged
    end,
    Mobiled = function(runtime, cursor, wan_if, wan_auto)
        local netchanged = false
        if wan_auto == "1" then
            cursor:set("network", wan_if, "auto", "0")
            netchanged = true
        end
        -- enable 3G/4G
        M.mobiled_enable(runtime, "1")
        return netchanged
    end,
    Mobiled_scheduled = function(runtime, cursor, wan_if, wan_auto)
        -- if timer expired then mode will change to Fixed_line
        local netchanged = false
        if wan_auto == "1" then
            cursor:set("network", wan_if, "auto", "0")
            netchanged = true
        end
        -- enable 3G/4G
        M.mobiled_enable(runtime, "1")
        M.tod_config(runtime, "1")
        return netchanged
    end,
}
function M.mobiled_check(runtime, l2state)
    local uci = runtime.uci
    local x = uci.cursor()
    local conn = runtime.ubus
    local wan_if=x:get("env", "custovar", "wan_if")
    local wan_auto = x:get("network", wan_if, "auto")
    local mode = x:get("wansensing", "global", "network_mode")
    local network_changed = false
    local handler = mode_handler[mode]
    if handler then
        if (mode == "Mobiled" or mode == "Mobiled_scheduled") then
            -- Check fixedline connectivity, which has top priority
            if (l2state ~= nil) then
                -- If L2 has connected (ETH/xDSL)...
                if wan_auto == "1" then
                    -- If fixedline is working, and do nothing. Directly return!!
                    return mode
                end

                -- Here the actual connection is being over Mobiled
                -- , and roll back to fixedline - Manual just effects one-time
                mode = "Fixed_line"
                handler = mode_handler[mode]

                x:set("wansensing", "global", "network_mode", mode)
                x:commit("wansensing")
            end
        end
        network_changed = handler(runtime, x, wan_if, wan_auto)
    end
    if network_changed then
        x:commit("network")
        conn:call("network", "reload", { })
    end
    return mode
end
return M
