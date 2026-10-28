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
    "device_config_changed",
    "platform_config_changed",
    "firmware_upgrade_start",
    "qualtest_start",
    "antenna_change_detected",
    "sim_removed"
}

function M.check(runtime, event, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log

    local retState = "DataSessionSetup"

    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        log:error(errMsg)
        return "WaitDeviceDisconnect"
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
    elseif require('mobiled.scripthelpers').startswith(event.event, "session_") or event.event == "timeout" then
        local info = device:get_network_info()
        if info and info.nas_state ~= "registered" then
            log:info("Network deregistered!")
            return "RegisterNetwork"
        end
        retState = "Idle"
        local dataSessionList = device:get_data_sessions()
        for i=#dataSessionList,1,-1 do
            local session = dataSessionList[i]
            log:info("Checking state for session " .. session.session_id)
            info = device:get_session_info(session.session_id)
            if info then
                log:info("Current state for session " .. session.session_id .. ": " .. info.session_state)
                if info.session_state == "disconnected" then
                    if session.deactivate then
                        mobiled.remove_data_session(device, session.session_id)
                        mobiled.propagate_session_state(device, "removed", { session })
                    else
                        local profile = mobiled.get_profile(session.profile_id)
                        if profile and not info.autoconnect then
                            mobiled.start_data_session(device, session.session_id, profile, session.interface)
                        end
                        session.changed = false
                        mobiled.propagate_session_state(device, info.session_state, { session })
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

    return retState
end

return M
