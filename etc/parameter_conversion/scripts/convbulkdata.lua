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

local function getSeed()
  local urand = assert (io.open ('/dev/urandom', 'rb'))
  local n, s = 0, urand:read (4)
  for i = 1, s:len () do
    n = 128 * n + s:byte (i)
  end
  return n
end

local function handleBulkdataReferencetime()
  math.randomseed(getSeed())
  n:foreach("bulkdata", "profile", function(s)
    local time_reference = s.time_reference
    if time_reference == "0001-01-01T00:00:00Z" then
      local curTime = os.time()
      local refer_second = math.random(curTime,curTime+s.report_interval)
      local refer_time = os.date("%Y-%m-%dT%H:%M:%SZ", refer_second)
      n:set("bulkdata", s[".name"], "time_reference", refer_time)
    end
  end)
end

handleBulkdataReferencetime()

n:commit("bulkdata")
