local M = {}

-- event = specifies the event which triggered this check method call (eg. timeout, mobiled_sim_initialized)
M.SenseEventSet = {
    "device_disconnected",
    "device_config_changed",
    "platform_config_changed",
    "firmware_upgrade_start",
    "qualtest_start"
}

--runtime = runtime environment holding references to ubus, uci, log
function M.check(runtime, event, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log
    local retState = "Disabled"

    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        log:error(errMsg)
        return "WaitDeviceDisconnect"
    end

    if event.event == "timeout" or event.event == "device_config_changed" then
        local config = mobiled.get_device_config(device)
        if not config.device.enabled then
            device:set_power_mode("lowpower")
            mobiled.propagate_session_state(device, "disconnected", device:get_data_sessions())
        else
            if device:set_power_mode("online") then
                retState = "SimInit"
            end
        end
    elseif (event.event == "platform_config_changed") then
        retState = "PlatformConfigure"
    elseif event.event == "device_disconnected" then
        retState = "DeviceRemove"
    elseif (event.event == "firmware_upgrade_start") then
        retState = "FirmwareUpgrade"
    elseif (event.event == "qualtest_start") then
        retState = "QualTest"
    end

    return retState
end

return M
