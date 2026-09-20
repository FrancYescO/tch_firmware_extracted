local M = {}

local pinType = "pin1"

-- event = specifies the event which triggered this check method call (eg. timeout, mobiled_sim_initialized)
M.SenseEventSet = {
    "puk_entered",
    "pin_entered",
    "device_disconnected",
    "device_config_changed",
    "firmware_upgrade_start"
}

--runtime = runtime environment holding references to ubus, uci, log
function M.check(runtime, event, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log
    local retState = "UnlockSim"

    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        log:error(errMsg)
        return "WaitDeviceDisconnect"
    end

    if event.event == "timeout" then
        local info = device:get_pin_info(pinType)
        if info then
            if(info.pin_state == "disabled" or info.pin_state == "enabled_verified") then
                retState = "RegisterNetwork"
            elseif(info.pin_state == "permanently_blocked") then
                retState = "InvalidSim"
            elseif(info.pin_state == "enabled_not_verified") then
                info = device:get_sim_info()
                local iccid = info.iccid
                if info.iccid_before_unlock == false then
                    iccid = "unknown"
                end
                --Check for "unknown" iccid in config, for migration case
                local pin = mobiled.get_pin_from_config(pinType, "unknown")
                if pin then
                    iccid = "unknown"
                end
                if mobiled.unlock_pin_from_config(device, pinType, iccid) then
                    if info.iccid_before_unlock == true and iccid == "unknown" then
                        if pin then
                            mobiled.store_pin_to_config(pinType, pin, info.iccid)
                            mobiled.remove_pin_from_config(pinType, iccid)
                        end
                    end
                    retState = "RegisterNetwork"
                end
            end
        end
    elseif event.event == "device_disconnected" then
        retState = "DeviceRemove"
    elseif (event.event == "puk_entered" or event.event == "pin_entered") then
        local info = device:get_pin_info(pinType)
        if info and (info.pin_state == "disabled" or info.pin_state == "enabled_verified") then
            retState = "RegisterNetwork"
        end
    elseif (event.event == "device_config_changed") then
        retState = "DeviceConfigure"
    elseif (event.event == "firmware_upgrade_start") then
        retState = "FirmwareUpgrade"
    end

    return retState
end

return M
