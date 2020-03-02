local error_handler = require("mobiled.error")

local valid_pdn_retry_causes = {
    [8] = true,
    [26] = true,
    [27] = true,
    [28] = true,
    [29] = true,
    [30] = true,
    [31] = true,
    [32] = true,
    [33] = true,
    [34] = true,
    [38] = true
}

local M = {}

M.SenseEventSet = {
    "network_scan_start",
    "network_deregistered",
    "session_disconnected",
    "session_connected",
    "session_teardown",
    "session_setup",
    "device_disconnected",
    "network_config_changed",
    "session_config_changed",
    "device_config_changed",
    "platform_config_changed",
    "firmware_upgrade_start",
    "qualtest_start",
    "antenna_change_detected",
    "pdn_retry_timer_expired",
    "sim_removed"
}

function M.check(runtime, event, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log

    local retState = "DataSessionSetup"

    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        if errMsg then log:error(errMsg) end
        return "DeviceRemove"
    end

    if event.event == "network_deregistered" then
        retState = "RegisterNetwork"
        mobiled.propagate_session_state(device, "disconnected", device:get_data_sessions())
    elseif event.event == "device_disconnected" then
        retState = "DeviceRemove"
    elseif event.event == "network_config_changed" then
        retState = "RegisterNetwork"
    elseif event.event == "network_scan_start" then
        retState = "NetworkScan"
    elseif (event.event == "device_config_changed") then
        retState = "DeviceConfigure"
    elseif (event.event == "platform_config_changed") then
        retState = "PlatformConfigure"
    elseif (event.event == "antenna_change_detected") then
        retState = "SelectAntenna"
    elseif (event.event == "firmware_upgrade_start") then
        retState = "FirmwareUpgrade"
    elseif (event.event == "qualtest_start") then
        retState = "QualTest"
    elseif (event.event == "sim_removed") then
        retState = "SimInit"
    elseif require('mobiled.scripthelpers').startswith(event.event, "session_") or event.event == "timeout" or event.event == "pdn_retry_timer_expired" then
        local info = device:get_network_info()
        if info and info.nas_state ~= "registered" then
            log:info("Network deregistered!")
            return "RegisterNetwork"
        end

        retState = "Idle"
        local dataSessionList = device:get_data_sessions()
        for i=#dataSessionList,1,-1 do
            local session = dataSessionList[i]

            -- In case any session related config changed, cancel the PDN retry timer
            if event.event == "session_config_changed" and session.pdn_retry_timer.timer then
                session.pdn_retry_timer.timer:cancel()
                session.pdn_retry_timer.timer = nil
                session.pdn_retry_timer.value = nil
                log:info("Canceled PDN retry timer")
            end

            -- Check if we need to start a PDN retry timer for the current reject cause
            if event.reject_cause and session.session_id == event.session_id and not session.pdn_retry_timer.timer then
                local cause = tonumber(event.reject_cause)
                log:warning(string.format('Data session setup attempt failed with error "%s"', error_handler.get_error_cause(cause) or "Unknown"))
                if cause and valid_pdn_retry_causes[cause] then
                    session.pdn_retry_timer.value = session.pdn_retry_timer.default_value
                    log:info(string.format("Starting PDN retry timer of %d seconds", session.pdn_retry_timer.value))
                    session.pdn_retry_timer.timer = runtime.uloop.timer(function()
                        session.pdn_retry_timer.timer = nil
                        log:info("PDN retry timer expired for session " .. session.session_id)
                        runtime.events.send_event("mobiled", { event = "pdn_retry_timer_expired", dev_idx = device.sm.dev_idx })
                    end, session.pdn_retry_timer.value * 1000)
                end
            end

            log:info("Checking state for session " .. session.session_id)
            info = device:get_session_info(session.session_id)
            if info then
                log:info("Current state for session " .. session.session_id .. ": " .. info.session_state)
                if info.session_state == "disconnected" then
                    if session.deactivate then
                        mobiled.remove_data_session(device, session.session_id)
                        mobiled.propagate_session_state(device, "removed", { session })
                    else
                        -- Check if we are allowed to try again
                        if not session.pdn_retry_timer.timer then
                            local profile = mobiled.get_profile(session.profile_id)
                            if profile and not info.autoconnect then
                                mobiled.start_data_session(device, session.session_id, profile, session.interface)
                            end
                            session.changed = false
                            mobiled.propagate_session_state(device, info.session_state, { session })
                        end
                        if not session.optional then
                            retState = "DataSessionSetup"
                        end
                    end
                elseif info.session_state == "connected" then
                    if session.deactivate or session.changed then
                        log:info("Deactivating session " .. tostring(session.session_id))
                        mobiled.stop_data_session(device, session.session_id, session.interface)
                        if not session.optional then
                            retState = "DataSessionSetup"
                        end
                    else
                        mobiled.propagate_session_state(device, info.session_state, { session })
                    end
                elseif info.session_state == "connecting" or info.session_state == "disconnecting" then
                    mobiled.propagate_session_state(device, info.session_state, { session })
                    if not session.optional then
                        retState = "DataSessionSetup"
                    end
                end
            else
                retState = "DataSessionSetup"
            end
        end
        if #dataSessionList == 0 then
            log:info("No activated data sessions")
        end
    end

    -- Reset the PDN retry timer(s) when leaving the DataSessionSetup state
    if retState ~= "DataSessionSetup" then
        local dataSessionList = device:get_data_sessions()
        for i=#dataSessionList,1,-1 do
            local session = dataSessionList[i]
            if session.pdn_retry_timer.timer then
                session.pdn_retry_timer.timer:cancel()
                session.pdn_retry_timer.timer = nil
            end
            session.pdn_retry_timer.value = nil
        end
    end

    return retState
end

return M
