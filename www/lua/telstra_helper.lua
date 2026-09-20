--  telstra_helper module
--  @module telstra_helper
--  @usage local tel_helper = require('telstra_helper')
--  @usage require('telstra_helper')

local M = {}
local proxy =  require("datamodel")
local landing_page = proxy.get("uci.env.var.landing_page")[1].value
if landing_page == "1" then
    M.symbolnamev1 = "Modem"
    M.symbolnamev2 = "modem"
    M.login_file = "landingpage.lp"
else
    M.symbolnamev1 = "Gateway"
    M.symbolnamev2 = "gateway"
    M.login_file = "loginbasic.lp"
end

function M.unsignedToSignedInt(value)
  if not value or type(value) ~= "number" then
    return ""
  end
  if bit.band(value, 128) == 128 then
    value = bit.bnot(value)
    value = bit.band(value, 255)
    value = "-" .. value + 1
  end
  return value
end

function M.getConnectionStrength(rssi, backhaul_interface_type)
  local connectionStatus = backhaul_interface_type == "Ethernet" and "Excellent" or "Good"
  if rssi and type(rssi) == "number" then
    if rssi <= -127 then
      connectionStatus = "No"
    elseif rssi < -85 then
      connectionStatus = "Weak"
    elseif rssi > -75 then
      connectionStatus = "Excellent"
    end
  end
  return connectionStatus
end
return M
