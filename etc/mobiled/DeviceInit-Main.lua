local M = {}

-- event = specifies the event which triggered this check method call (eg. timeout, device_initialized)
M.SenseEventSet = {
    "device_initialized",
    "device_disconnected",
    "device_config_changed"
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
        if info and info.initialized and info.imei then
            -- Store the IMEI for fast access to the device
            device.imei = info.imei
            retState = "DeviceConfigure"
        end
    elseif event.event == "device_disconnected" then
        retState = "DeviceRemove"
    end

    return retState
end

return M
