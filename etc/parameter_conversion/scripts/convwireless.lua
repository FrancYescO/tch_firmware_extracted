local uc = require("uciconv")
local newConfig = uc.uci('new')

newConfig:foreach("wireless", "wifi-ap", function(s)
  for option, value in pairs(s) do
    if option == "security_mode" and  value == "wpa2" then
      newConfig:set("wireless", s[".name"], option, "wpa2-psk")
    end
  end
end)

newConfig:foreach("wireless", "wifi-ap", function(s)
  for option, value in pairs(s) do
    if option == "supported_security_modes" then
      local modes = ""
      for str in string.gmatch(value, "([^".."%s".."]+)") do
        if str ~= "wpa2" then
          modes = modes .. str .. " "
        end
      end
      modes = modes:sub(1,-2)
      newConfig:set("wireless", s[".name"], option, modes)
    end
  end
end)

newConfig:commit("wireless")
