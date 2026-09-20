local format = string.format
local uci = require 'transformer.mapper.ucihelper'

local M = {}

local function load_uci_defaults(ap)
  local ap_binding = {config="ucidefaults", sectionname=ap.."_defaults"}
  return uci.getall_from_uci(ap_binding)
end

local function load_default_values(ap)
  if ap and string.match(ap, "ap%d+$") then
    local options = { "wep_key", "wpa_psk_key", "wps_ap_pin", "security_mode" }
    local defaults = {}
    local values = load_uci_defaults(ap)
    if next(values) then
      for option, varname in pairs(options) do
        local v = values[varname] or ''
        defaults[varname] = v
      end
      return defaults
    end
  end
  return nil
end

local wireless_ap = {config="wireless"}
local function apply_defaults(ap, defaults, commitapply)
  wireless_ap.sectionname = ap
  for option, value in pairs(defaults) do
    wireless_ap.option = option
    uci.set_on_uci(wireless_ap, value, commitapply)
  end
  return true
end

function M.reset(ap, commitapply)
  local defaults = load_default_values(ap)
  if defaults then
    return apply_defaults(ap, defaults, commitapply)
  end
  return nil, "no defaults found for this AccessPoint"
end

return M
