local uc = require("uciconv")
local o = uc.uci('old')

-- Give names to some of the anonymous rules in firewall
o:foreach('firewall', 'rule', function(s)
  if s[".anonymous"] then
    if s['name'] == "Allow-Encapsulated-IPv6" then
      o:rename("firewall", s[".name"], "Allow_Encapsulated_IPv6")
    elseif s['name'] == "Restrict-TCP-LAN-Input" then
      o:rename("firewall", s[".name"], "Restrict_TCP_LAN_Input")
    end
  end
end)

o:commit('firewall')
