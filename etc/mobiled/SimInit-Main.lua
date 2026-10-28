local M = {}

-- event = specifies the event which triggered this check method call (eg. timeout, mobiled_sim_initialized)
M.SenseEventSet = {
    "sim_initialized",
    "device_disconnected",
    "device_config_changed",
    "firmware_upgrade_start",
    "platform_config_changed",
    "qualtest_start"
}

--runtime = runtime environment holding references to ubus, uci, log
function M.check(runtime, event, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log

    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        log:error(errMsg)
        return "WaitDeviceDisconnect"
    end

    if (event.event == "timeout" or event.event == "sim_initialized") then
        local info = device:get_sim_info()
        if info and (info.iccid or info.iccid_before_unlock == false) then
            if info.iccid_before_unlock == false then
                device.iccid = "unknown"
            else
                device.iccid = info.iccid
            end
            if info.sim_state == "locked" or info.sim_state == "blocked" then
                return "UnlockSim"
            elseif info.sim_state == "ready" then
                info = device:get_pin_info()
                if info then
                    if info.pin_state == "enabled_verified" or info.pin_state == "disabled" then
                        return "SelectAntenna"
                    else
                        return "UnlockSim"
                    end
                end
            end
        end
    elseif event.event == "device_disconnected" then
        return "DeviceRemove"
    elseif (event.event == "device_config_changed") then
        return "DeviceConfigure"
    elseif (event.event == "firmware_upgrade_start") then
        return "FirmwareUpgrade"
    elseif (event.event == "platform_config_changed") then
        return "PlatformConfigure"
    elseif (event.event == "qualtest_start") then
        return "QualTest"
    end

    return "SimInit"
end

return M
