local uci = require('uci')
local cursor = uci.cursor()
local popen = io.popen
local M = {}

function M.start(runtime, actionname, object)
   runtime.logger:info("calling script M start (" .. actionname .. ")")
   local tod_mac = cursor:get("tod", actionname, "id")
   runtime.logger:info("MAC  is (" .. tod_mac .. ")")
   local neighbors = popen("ip neigh")
   if neighbors then
      for n in neighbors:lines() do
          local ip, dev, mac = n:match("(.+) dev (.+) lladdr (.+) ")
          if mac == string.lower(tod_mac) and dev:match("lan") then
             runtime.logger:info("IP  is (" .. ip .. ")")
             os.execute("conntrack -D -s " .. ip)
             os.execute("conntrack -D -r " .. ip)
          end
      end
      neighbors:close()
   end
   return true
end

function M.stop(runtime, actionname, object)
    runtime.logger:info("calling script M stop")
    return true
end

return M
