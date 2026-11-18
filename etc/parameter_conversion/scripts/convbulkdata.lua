uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')

local v, name
o:foreach("bulkdata", "profile", function(s)
  name = s[".name"]
  v = o:get("bulkdata", name, "http_url")
    if  v == "http://abc.com" then
      n:set("bulkdata", name, "http_url", "http://")
      if name:match("^profile_") then
        n:set("bulkdata", name, "http_username", "")
        n:set("bulkdata", name, "http_password", "")
      end
    end
end)

n:commit("bulkdata")
