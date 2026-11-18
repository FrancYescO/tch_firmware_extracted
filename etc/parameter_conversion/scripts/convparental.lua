local uc = require("uciconv")
local newConfig = uc.uci('new')
local match = string.match

function getURLDomain(site)
  --extract only domain part in URL
  site = site:match("[%w]+://([^/ ]*)") or site:match("([^/ ]*)") or site
  -- check if the site starts with www then remove it from URL.
  return site:match("^www%.(%S+)") or site
end

newConfig:foreach("parental", "URLfilter", function(s)
  for option, value in pairs(s) do
    value = tostring(value)
    if option == "device" then
      if value == "All" or value == value:match("%d+%.%d+%.%d+%.%d+") then
        newConfig:set("parental", s[".name"], option, "single")
      else
        newConfig:set("parental", s[".name"], option, value)
      end
    elseif option == "site" then
      value = getURLDomain(value)
      newConfig:set("parental", s[".name"], option, value)
    elseif option ~= "_key" then
      newConfig:set("parental", s[".name"], option, value)
    end
  end
end)

newConfig:commit("parental")
