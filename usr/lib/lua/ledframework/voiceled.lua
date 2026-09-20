local M = {}
---
---- returns 'true' or 'false' for identifying the device led on/off
---- @function [parent=#voiceled] getFxsDeviceLedStatus
---- @param device: the name of the fxs device, such as fxs_dev_0 or fxs_dev_1
---- @param status: device status in the ubus mmpbx.device
---- @param profile_valid: all the profile combinated status of enable and usable in the ubus mmpbx.profile
function M.getFxsDeviceLedStatus(device, status, profile_valid)
    return ((status["deviceUsable"] == true) and (status["profileUsable"]))
end

return M
