local uc = require("uciconv")
local oldConfig = uc.uci('old')
local newConfig = uc.uci('new')

-- ethernet
oldConfig:foreach("ethernet", "trafficdesc", function(s)
    local name = s[".name"]
    if s.mbs ~= nil then
      newConfig:set("ethernet", name, "max_burst_size", s.mbs)
      newConfig:delete("ethernet", name, "mbs")
    end
    if s.mbr ~= nil then
      newConfig:set("ethernet", name, "max_bit_rate", s.mbr)
      newConfig:delete("ethernet", name, "mbr")
    end
end)
newConfig:commit("ethernet")

-- xtm
oldConfig:foreach("xtm", "trafficdesc", function(s)
    local name = s[".name"]
    if s.mcr ~= nil then
      newConfig:set("xtm", name, "min_cell_rate", s.mcr)
      newConfig:delete("xtm", name, "mcr")
    end
    if s.mbs ~= nil then
      newConfig:set("xtm", name, "max_burst_size", s.mbs)
      newConfig:delete("xtm", name, "mbs")
    end
    if s.pcr ~= nil then
      newConfig:set("xtm", name, "peak_cell_rate", s.pcr)
      newConfig:delete("xtm", name, "pcr")
    end
    if s.scr ~= nil then
      newConfig:set("xtm", name, "sustained_cell_rate", s.scr)
      newConfig:delete("xtm", name, "scr")
    end
end)
newConfig:commit("xtm")

-- qos
oldConfig:foreach("qos", "class", function(s)
    local name = s[".name"]
    if s.mbr ~= nil then
      newConfig:set("qos", name, "min_bit_rate", s.mbr)
      newConfig:delete("qos", name, "mbr")
    end
    if s.pbr ~= nil then
      newConfig:set("qos", name, "peak_cell_rate", s.pbr)
      newConfig:delete("qos", name, "pbr")
    end
    if s.mbs ~= nil then
      newConfig:set("qos", name, "max_burst_size", s.mbs)
      newConfig:delete("qos", name, "mbs")
    end
end)
newConfig:commit("qos")
