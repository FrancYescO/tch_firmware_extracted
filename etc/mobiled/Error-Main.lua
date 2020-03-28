local M = {}

-- event = specifies the event which triggered this check method call (eg. timeout, mobiled_sim_initialized)
M.SenseEventSet = {
    "device_disconnected"
}

--runtime = runtime environment holding references to ubus, uci, log
function M.check(runtime, event, dev_idx)
    return "Error"
end

return M
