local M = {}

function M.entry(runtime, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log

    log:notice("DeviceInit-> Entry Function")

    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        if errMsg then log:error(errMsg) end
        return false
    end

    local ret
    ret, errMsg = device:init_device()
    if not ret then
        if errMsg then log:error(errMsg) end
        runtime.mobiled.remove_device(device)
        -- Workaround for GCT module not initializing correctly
        if mobiled.platform and mobiled.platform.module_power_off and mobiled.platform.module_power_on then
            mobiled.platform.module_power_off()
            require('mobiled.scripthelpers').sleep(2)
            mobiled.platform.module_power_on()
        end
        return false
    end

    return true
end

function M.exit(runtime, transition, dev_idx)
    return true
end

return M
