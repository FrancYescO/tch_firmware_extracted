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
    "device_config_changed"
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
    elseif require('mobiled.scripthelpers').startswith(event.event, "session_") or event.event == "timeout" then
        retState = "Idle"
        local dataSessionList = device:get_data_sessions()
        for i=#dataSessionList,1,-1 do
            local session = dataSessionList[i]
            log:info("Checking state for session " .. session.session_id)
            local info = device:get_session_info(session.session_id)
            if info then
                if info.always_on == true and info.autoconnect == true then
                    if info.idletime then log:info("Autoconnect session with " .. info.idletime .. " seconds timeout") end
                    log:info("Nothing to do here")
                else
                    log:info("Current state for session " .. session.session_id .. ": " .. info.session_state)
                    if info.session_state == "disconnected" then
                        if session.deactivate then
                            mobiled.remove_data_session(device, session.session_id)
                            mobiled.propagate_session_state(device, "removed", { session })
                        else
                            local profile = mobiled.get_profile(session.profile_id)
                            if profile then
                                mobiled.start_data_session(device, session.session_id, profile, session.interface)
                            end
                            session.changed = false
                            mobiled.propagate_session_state(device, info.session_state, { session })
                            retState = "DataSessionSetup"
                        end
                    elseif info.session_state == "connected" then
                        if session.deactivate or session.changed then
                            log:info("Deactivating session " .. tostring(session.session_id))
                            mobiled.stop_data_session(device, session.session_id, session.interface)
                            retState = "DataSessionSetup"
                        else
                            mobiled.propagate_session_state(device, info.session_state, { session })
                        end
                    elseif info.session_state == "connecting" or info.session_state == "disconnecting" then
                        mobiled.propagate_session_state(device, info.session_state, { session })
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
