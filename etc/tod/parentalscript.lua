local uci = require('uci')
local ubus
local pairs = pairs
local os = os
local M = {}

function M.start(runtime, actionname, object)
  ubus = runtime.ubus
  local mac = cursor:get("tod", actionname, "id")
  local devs = ubus:call("hostmanager.device", "get",{}) or {}
  for x,y in pairs(devs) do
   if x and devs[x]["mac-address"] == mac then
     for _, idx in pairs(devs[x]["ipv4"]) do
       if idx["state"] and idx["state"] == "connected" then
         os.execute(string.format("conntrack -D -s %s", idx["address"]))
       end
     end
     for _,idx in pairs(devs[x]["ipv6"]) do
       if idx["state"] and idx["state"] == "connected" then                         
         os.execute(string.format("conntrack -D -s %s", idx["address"]))
       end
     end
   end
  end
end

function M.stop(runtime, actionname, object)
  return true
end

return M
