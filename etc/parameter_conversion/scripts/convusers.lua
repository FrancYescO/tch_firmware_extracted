local uc = require("uciconv")
local oldConfig = uc.uci('old')
local newConfig = uc.uci('new')

local guestUsers = {}

oldConfig:foreach("web", "user", function(s)
  if s.role == "guest" then
    guestUsers[#guestUsers+1] = s[".name"]
    newConfig:delete('web', s[".name"])
  end
end)

oldConfig:foreach("web", "sessionmgr", function(s)
  if s[".name"] == "default" then
    for i,v in ipairs(s.users) do
      for index,b in ipairs(guestUsers) do
        if s.users[i] == guestUsers[index] then
          table.remove(s.users, i)
          newConfig:set("web", "default", "users", s.users)
        end
      end
    end
  end
end)

oldConfig:foreach("web", "rule", function(s)
  for i,v in ipairs(s.roles) do
    if s.roles[i] == "guest" then
        table.remove(s.roles, i)
        newConfig:set("web", s[".name"], "roles", s.roles)
    end
  end
end)

newConfig:commit("web")
