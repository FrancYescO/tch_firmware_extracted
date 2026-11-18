local M = {}

-- event = specifies the event which triggered this check method call (eg. timeout, device_initialized)
M.SenseEventSet = {
    "device_initialized",
    "device_disconnected",
    "device_config_changed",
    "platform_config_changed"
}

--runtime = runtime environment holding references to ubus, uci, log
function M.check(runtime, event, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log
    local retState = "DeviceInit"

    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        log:error(errMsg)
        return "WaitDeviceDisconnect"
    end

    if event.event == "timeout" or event.event == "device_initialized" or event.event == "device_config_changed" then
        local info = device:get_device_info()
        if info and info.initialized then
            if not device.info then
                device.info = {}
            end
            -- Some devices don't support reading the IMEI so allow Mobiled to use any other parameter to link the config
            device.info.device_config_parameter = info.device_config_parameter or "imei"
            if info[device.info.device_config_parameter] then
                device.info[device.info.device_config_parameter] = info[device.info.device_config_parameter]
                device.info.model = info.model
                retState = "DeviceConfigure"
            end
        end
    elseif (event.event == "platform_config_changed") then
        retState = "PlatformConfigure"
    elseif event.event == "device_disconnected" then
        retState = "DeviceRemove"
    end

    return retState
end

return M
