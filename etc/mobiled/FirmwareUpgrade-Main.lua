local M = {}

M.SenseEventSet = {
    "device_disconnected",
    "firmware_upgrade_done"
}

function M.check(runtime, event, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log
    local retState = "FirmwareUpgrade"
    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        if errMsg then log:error(errMsg) end
        return "WaitDeviceDisconnect"
    end

    if event.event == "timeout" or event.event == "firmware_upgrade_done" then
        local info = device:get_firmware_upgrade_info()
        if info and info.status then log:info("Firmware upgrade status: " .. info.status) end
    elseif event.event == "device_disconnected" then
        retState = "DeviceRemove"
    end
    return retState
end

return M
