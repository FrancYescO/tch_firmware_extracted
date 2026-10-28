local M = {}

function M.entry(runtime, dev_idx)
    local mobiled = runtime.mobiled
    local log = runtime.log
    log:notice("RegisterNetwork-> Entry Function")
    local device, errMsg = mobiled.get_device(dev_idx)
    if not device then
        log:error(errMsg)
        return
    end
    mobiled.register_network(device)
    return true
end

function M.exit(runtime, transition, dev_idx)
    local log = runtime.log
    log:notice("RegisterNetwork-> Exit Function")
    return true
end

return M
