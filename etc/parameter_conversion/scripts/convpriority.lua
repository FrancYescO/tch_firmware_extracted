local uc = require("uciconv")
local oldConfig = uc.uci('old')
local newConfig = uc.uci('new')

oldConfig:foreach("qos", "label", function(s)
    local name = s[".name"]
    if name == "gamingpriority" then
      newConfig:set("qos", name, "label")
      newConfig:set("qos", name, "trafficid", s.trafficid)
    end
end)

oldConfig:foreach("qos", "reclassify", function(s)
    local name = s[".name"]
    if s.srcmac then
      newConfig:set("qos", name, "reclassify")
      newConfig:set("qos", name, "srcmac", s.srcmac)
      newConfig:set("qos", name, "target", s.target)
    end
end)
newConfig:commit("qos")
