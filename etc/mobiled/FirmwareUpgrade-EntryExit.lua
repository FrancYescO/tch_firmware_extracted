local M = {}

function M.entry(runtime, dev_idx)
    local log = runtime.log
    local mobiled = runtime.mobiled
    log:notice("FirmwareUpgrade-> Entry Function")
    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        if errMsg then log:error(errMsg) end
        return nil, "No such device"
    end
    if device.info.firmware_upgrade and device.info.firmware_upgrade.path then
        return device:firmware_upgrade(device.info.firmware_upgrade.path)
    end
    return true
end

function M.exit(runtime, dev_idx)
    local log = runtime.log
    log:notice("FirmwareUpgrade-> Exit Function")
    return true
end

return M
