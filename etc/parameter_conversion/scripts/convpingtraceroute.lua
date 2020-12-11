local uc = require("uciconv")
local newConfig = uc.uci('new')

newConfig:foreach("traceroute", "user", function(s)
        if newConfig:get("traceroute", s[".name"], "type") == nil then
          newConfig:set("traceroute", s[".name"], "type", "IPv4")
        end
end)
newConfig:commit("traceroute")

newConfig:foreach("ipping", "user", function(s)
        if newConfig:get("ipping", s[".name"], "iptype") == nil then
          newConfig:set("ipping", s[".name"], "iptype", "IPv4")
        end
end)

newConfig:commit("ipping")
