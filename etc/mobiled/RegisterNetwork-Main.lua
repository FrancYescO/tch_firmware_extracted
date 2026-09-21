local M = {}

M.SenseEventSet = {
    "network_scan_start",
    "network_deregistered",
    "network_registered",
    "device_disconnected",
    "network_config_changed",
    "device_config_changed",
    "firmware_upgrade_start"
}

function M.check(runtime, event, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log

    local retState = "RegisterNetwork"

    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        log:error(errMsg)
        return "WaitDeviceDisconnect"
    end

    if event.event == "timeout" or event.event == "network_deregistered" or event.event == "network_registered" then
        local info = device:get_network_info()
        if info then
            if info.nas_state then log:info("Current NAS state: " .. info.nas_state) end
            if info.nas_state == "registered" then
                retState = "DataSessionSetup"
            elseif info.nas_state ~= "not_registered_searching" then
                mobiled.register_network(device)
            end
        end
    elseif event.event == "network_config_changed" then
        mobiled.register_network(device)
    elseif event.event == "device_disconnected" then
        retState = "DeviceRemove"
    elseif event.event == "network_scan_start" then
        retState = "NetworkScan"
    elseif (event.event == "device_config_changed") then
        retState = "DeviceConfigure"
    elseif (event.event == "firmware_upgrade_start") then
        retState = "FirmwareUpgrade"
    end

    return retState
end

return M
