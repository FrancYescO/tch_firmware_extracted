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
        if errMsg then log:error(errMsg) end
        return "DeviceRemove"
    end

    if event.event == "device_config_changed" then
        retState = "DeviceConfigure"
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
