local M = {}

-- event = specifies the event which triggered this check method call (eg. timeout, device_initialized)
M.SenseEventSet = {
    "device_disconnected",
    "device_config_changed"
}

--runtime = runtime environment holding references to ubus, uci, log
function M.check(runtime, event, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log
    local retState = "DeviceConfigure"

    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        if errMsg then log:error(errMsg) end
        return "WaitDeviceDisconnect"
    end

    if event.event == "device_disconnected" then
        retState = "DeviceRemove"
    else
        local config = mobiled.get_config()
        if config.platform and config.platform.antenna then
            if mobiled.platform and mobiled.platform.select_antenna then
                mobiled.platform.select_antenna(config.antenna)
            end
        end
        config = mobiled.get_device_config(device)
        if config and config.device then
            if config.device.enabled == false then
                if device:set_power_mode("lowpower") then
                    retState = "Disabled"
                end
            else
                if device:set_power_mode("online") then
                    retState = "SimInit"
                end
            end
        end
    end

    return retState
end

return M
