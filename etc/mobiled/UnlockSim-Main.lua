local M = {}

local pinType = "pin1"

-- event = specifies the event which triggered this check method call (eg. timeout, mobiled_sim_initialized)
M.SenseEventSet = {
    "puk_entered",
    "pin_entered",
    "device_disconnected",
    "device_config_changed",
    "firmware_upgrade_start",
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

    if event.event == "timeout" then
        local info = device:get_pin_info(pinType)
        if info then
            if(info.pin_state == "disabled" or info.pin_state == "enabled_verified") then
                return "SelectAntenna"
            elseif(info.pin_state == "permanently_blocked") then
                return "InvalidSim"
            elseif(info.pin_state == "enabled_not_verified") then
                info = device:get_sim_info()
                if info.iccid_before_unlock == false then
                    info.iccid = "unknown"
                end
                if mobiled.unlock_pin_from_config(device, pinType, info.iccid) then
                    return "SelectAntenna"
                end
            end
        end
    elseif event.event == "device_disconnected" then
        return "DeviceRemove"
    elseif (event.event == "puk_entered" or event.event == "pin_entered") then
        return "SelectAntenna"
    elseif (event.event == "device_config_changed") then
        return "DeviceConfigure"
    elseif (event.event == "firmware_upgrade_start") then
        return "FirmwareUpgrade"
    elseif (event.event == "qualtest_start") then
        return "QualTest"
    end

    return "UnlockSim"
end

return M
