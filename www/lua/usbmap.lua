
local M = {}

local untaint_mt = require("web.taint").untaint_mt

-- The USB port numbers (on the housing) on a vant-f are reversed with the internal ones
local labelmap = setmetatable({
  ['1'] = '2',
  ['2'] = '1'
}, untaint_mt)

-- This function returns the USB port number based on a given directory name
-- created in /sys/bus/usb/devices/ when a USB storage device is inserted.
-- Expected input: Directory Name
-- Return value: USB Port Label
function M.get_usb_label(port)
  return labelmap[port:match('.*%-(%d+)')]
end

return M