local M = {}

M.SenseEventSet = {
    "network_scan_start",
    "network_deregistered",
    "network_registered",
    "device_disconnected",
    "network_config_changed",
    "device_config_changed",
    "platform_config_changed",
    "firmware_upgrade_start",
    "qualtest_start",
    "antenna_change_detected",
    "sim_removed"
}

function M.check(runtime, event, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log

    local retState = "RegisterNetwork"

    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        if errMsg then log:error(errMsg) end
        return "DeviceRemove"
    end

    if event.event == "timeout" or event.event == "network_deregistered" or event.event == "network_registered" then
        local config = mobiled.get_config()
        local info = device:get_sim_info()
        if info and info.imsi then
            if type(config.allowed_imsi_ranges) == "table" then
                local match = false
                for _, imsi in pairs(config.allowed_imsi_ranges) do
                    if string.match(info.imsi, imsi) then
                        match = true
                        break
                    end
                end
                if not match then
                    mobiled.add_error(device, "fatal", "invalid_sim", "Invalid IMSI")
                    return "Error"
                end
            end
        end
        info = device:get_network_info()
        if info then
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
    elseif (event.event == "platform_config_changed") then
        retState = "PlatformConfigure"
    elseif (event.event == "firmware_upgrade_start") then
        retState = "FirmwareUpgrade"
    elseif (event.event == "qualtest_start") then
        retState = "QualTest"
    elseif (event.event == "antenna_change_detected") then
        retState = "SelectAntenna"
    elseif (event.event == "sim_removed") then
        retState = "SimInit"
    end

    return retState
end

return M
