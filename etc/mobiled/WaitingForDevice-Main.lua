local M = {}
local detector = require('mobiled.detector')

-- event = specifies the event which triggered this check method call (eg. timeout, mobiled_device_detected)
M.SenseEventSet = {
    "device_connected"
}

--runtime = runtime environment holding references to ubus, uci, log
function M.check(runtime, event, dev_idx)
    local log = runtime.log
    local retState = "WaitingForDevice"

    if event.event == "timeout" or event.event == "device_connected" then
        local dev, msg = detector.scan(runtime)
        if dev then
            retState = "DeviceInit"
        else
            if msg then log:error("Failed to add device (" .. msg .. ")") end
        end
    end

    return retState
end

return M
