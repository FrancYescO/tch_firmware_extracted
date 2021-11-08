local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')

o:foreach('firewall', 'cone', function(s)
  if s[".anonymous"] then
    local newName = s['name']:gsub(" ", "")
    o:rename("firewall", s[".name"], newName)
  end
end)
o:commit('firewall')
