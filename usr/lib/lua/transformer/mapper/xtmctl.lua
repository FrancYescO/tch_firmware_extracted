-- helper functions to wrap xtmctl utility from broadcom
local popen = io.popen
local execute = os.execute
local match = string.match
local log = require("transformer.logger").new("mapper.xtmctl", 2)

local M = {}

-- get status of XtmDevice
-- \param addr [<port_mask.vpi.vci>|<port_mask.ptmpri_mask>]]
-- \returns enabled or disabled for valid addr, otherwise ""
function M.getXtmDeviceStatus(addr)
  local pipe = popen("xtmctl operate conn --show " .. addr)
  if not pipe then
    return ""
  end

  local status = ""
  for line in pipe:lines() do
    if match(line, "^ATM") or match(line, "^PTM") then
      status = match(line, "enabled") or match(line, "disabled") or ""
      break
    end
  end
  pipe:close()
  return status
end

-- enable/disable xtm device
-- \param addr [<port_mask.vpi.vci>|<port_mask.ptmpri_mask>]]
-- \param bActive (bool) if true enable else disable
-- \returns true if disable works, otherwise return false
function M.enableXtmDevice(addr, bActive)
  if execute("xtmctl operate conn --state " .. addr .. " " .. bActive and "enable" or "disable") ~= 0 then
    log:error("enable/disable XTM Device failed")
    return false
  end
end

return M
