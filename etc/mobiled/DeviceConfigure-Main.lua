local M = {}

-- event = specifies the event which triggered this check method call (eg. timeout, device_initialized)
M.SenseEventSet = {
    "device_disconnected",
    "device_config_changed",
    "platform_config_changed"
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
        return "DeviceRemove"
    elseif event.event == "platform_config_changed" then
        return "PlatformConfigure"
    else
        local config = mobiled.get_device_config(device)
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
            local info = device:get_device_info()
            if info and info.login_required then
                retState = "DeviceConfigure"
                if config.device.username and config.device.password then
                    log:info("Logging in to device using " .. config.device.username .. " " .. config.device.password)
                    if device:login(config.device.username, config.device.password) then
                        retState = "SimInit"
                    end
                end
            end
        else
            log:error("No config for device!")
        end
    end

    return retState
end

return M
