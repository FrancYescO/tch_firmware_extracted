local M = {
    timeout = 300
}

M.SenseEventSet = {
    "device_disconnected",
    "firmware_upgrade_done",
    "firmware_upgrade_failed",
    "network_deregistered",
    "session_disconnected"
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
        if event.event == "timeout" and tonumber(event.timeout) then
            -- The first time we come here is in a state transition so not a real timeout
            if not device.info.firmware_upgrade.timeout then
                device.info.firmware_upgrade.timeout = 0
            else
                device.info.firmware_upgrade.timeout = device.info.firmware_upgrade.timeout + event.timeout
            end
            if device.info.firmware_upgrade.timeout > M.timeout then
                log:error("Timeout in FirmwareUpgrade after " .. device.info.firmware_upgrade.timeout .. " seconds")
                runtime.events.send_event("mobiled.firmware_upgrade", { status = "timeout", dev_idx = device.sm.dev_idx })
                retState = "DeviceInit"
            end
        end
        local info = device:get_firmware_upgrade_info()
        if info and info.status then
            if info.status == "not_running" or info.status == "done" or info.status == "failed" or info.status == "no_upgrade_available" then
                log:info(string.format('FirmwareUpgrade completed with status "%s" after %d seconds', info.status, device.info.firmware_upgrade.timeout))
                retState = "DeviceInit"
            end
        end
    elseif event.event == "device_disconnected" then
        retState = "DeviceRemove"
    elseif event.event == "network_deregistered" then
        mobiled.propagate_session_state(device, "disconnected", device:get_data_sessions())
    elseif event.event == "session_disconnected" and event.session_id then
        mobiled.propagate_session_state(device, "disconnected", {{ session_id = event.session_id }})
    end
    return retState
end

return M
