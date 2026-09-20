local cursor = require('uci').cursor()

local M = {}

---
---- returns 'true' or 'false' for identifying the device led on/off
---- @function [parent=#voiceled] getFxsDeviceLedStatus
---- @param device: the name of the fxs device, such as fxs_dev_0 or fxs_dev_1
---- @param status: device status in the ubus mmpbx.device
---- @param profile_valid: all the profile combinated status of enable and usable in the ubus mmpbx.profile
function M.getFxsDeviceLedStatus(device, status, profile_valid)
    if ((status["deviceUsable"] == true) and (status["profileUsable"] == 'true')) then
        local profiles
        cursor:foreach('mmpbx', 'outgoing_map', function(s)
            if(s['device'] == device) then
                profiles = s['profile']
                return false
            end
        end)
        for _, profile in pairs(profiles) do
            if profile ~= 'fxo_profile' and profile_valid[profile] then
                return 'true'
            end
        end
    end
    return 'false'
end

return M
