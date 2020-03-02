local M = {}

-- event = specifies the event which triggered this check method call (eg. timeout, sim_initialized)
M.SenseEventSet = {
    "network_scan_start",
    "network_deregistered",
    "session_disconnected",
    "session_connected",
    "session_teardown",
    "session_setup",
    "device_disconnected",
    "session_config_changed",
    "network_config_changed",
    "device_config_changed",
    "platform_config_changed",
    "firmware_upgrade_start",
    "pco_update_received",
    "qualtest_start",
    "antenna_change_detected",
    "sim_removed"
}

--runtime = runtime environment holding references to ubus, uci, log
function M.check(runtime, event, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log
    local retState = "Idle"

    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        if errMsg then log:error(errMsg) end
        return "DeviceRemove"
    end

    if event.event == "timeout" then
        local info = device:get_network_info()
        if info and info.nas_state ~= "registered" then
            return "RegisterNetwork"
        end
        local dataSessionList = device:get_data_sessions()
        for _, session in pairs(dataSessionList) do
            info = device:get_session_info(session.session_id)
            if info then
                if not session.optional and (info.session_state == "disconnected" or info.session_state == "") then
                    return "DataSessionSetup"
                end
            end
        end
    else
        if event.event == "network_deregistered" then
            retState = "RegisterNetwork"
            mobiled.propagate_session_state(device, "disconnected", device:get_data_sessions())
        elseif event.event == "device_disconnected" then
            retState = "DeviceRemove"
        elseif require('mobiled.scripthelpers').startswith(event.event, "session_") or event.event == "pco_update_received" then
            retState = "DataSessionSetup"
        elseif event.event == "network_scan_start" then
            retState = "NetworkScan"
        elseif event.event == "network_config_changed" then
            retState = "RegisterNetwork"
        elseif (event.event == "device_config_changed") then
            retState = "DeviceConfigure"
        elseif (event.event == "platform_config_changed") then
            retState = "PlatformConfigure"
        elseif (event.event == "firmware_upgrade_start") then
            retState = "FirmwareUpgrade"
        elseif (event.event == "qualtest_start") then
            retState = "QualTest"
        elseif (event.event == "antenna_change_detected") then
            retState = "SelectAntenna"
        elseif (event.event == "sim_removed") then
            retState = "SimInit"
        end
    end

    return retState
end

return M
