local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')

local haveOldRARule
o:foreach('firewall', 'rule', function(s)
  if s['name'] == "ACCEPT" or s['name'] == 'DROP' then
    haveOldRARule = true
    return false
  end
end)

if haveOldRARule then
  n:foreach('firewall', 'rule', function(s)
    if s['name'] == "ACCEPT" then
      n:set('firewall', s['.name'], 'name', 'Dev_Allow_Access')
    elseif s['name'] == 'DROP' then
      n:set('firewall', s['.name'], 'name', 'Dev_Deny_Access')
    end
  end)
  n:commit('firewall')
end
