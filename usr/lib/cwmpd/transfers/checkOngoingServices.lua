local ubus = require("ubus")
local uci = require("uci")
local cursor = uci.cursor()
local conn = ubus.connect()
local next = next
if not conn then return end

local function callOngoing()
  local calls = {}
  calls = conn:call("mmpbx.call", "get", {})
  if type(calls) == "table" then
    if next(calls) ~= nil then
      return true
    end
  end
  return false
end

local function vodPorts()
  local ports={}
  cursor:foreach("firewall", "rule", function(s)
    if s["set_helper"] == "rtsp" then
      table.insert(ports,s.dest_port)
    end
  end)
  cursor:foreach("firewall_helpers", "helper", function(s)
    if s["name"] == "rtsp" then
      table.insert(ports,s.port)
    end
  end)
  return ports
end

local function vodOngoing(dest_ports)
  if not dest_ports or #dest_ports == 0 then
    return false
  end
  local conntrack = io.popen("conntrack -L 2>/dev/null")
  if not conntrack then
    return false
  end
  for line in conntrack:lines() do
     for _, port in ipairs(dest_ports) do
        local match = "dport=" .. port
        if line:find(match) then
          conntrack:close()
          return true
        end
     end
  end
  conntrack:close()
  return false
end

function wait()
  local ports = vodPorts()
  local blockOnVod = cursor:get("cwmpd", "cwmpd_config", "delay_upgrade_vod") == "1"
  while(callOngoing() or (blockOnVod and vodOngoing(ports))) do
    os.execute("sleep 5")
  end
end

wait()
