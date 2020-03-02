local uc = require("uciconv")
local newConfig = uc.uci('new')
local match = string.match

newConfig:foreach("parental", "URLfilter", function(s)
  for k,v in pairs(s) do
  v = tostring(v)
  if k == "device" then
   if v == "All" or v == v:match("%d+%.%d+%.%d+%.%d+") then
    newConfig:set("parental", s[".name"], k, "single")
   else
    newConfig:set("parental", s[".name"], k, v)
   end
  elseif k ~= "_key" then
   newConfig:set("parental", s[".name"], k, v)
  end
  end
end)

newConfig:commit("parental")
