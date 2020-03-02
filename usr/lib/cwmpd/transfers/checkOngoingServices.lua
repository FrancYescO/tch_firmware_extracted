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

function vodPort()
  local port
  cursor:foreach("firewall", "helper", function(s)
    if s["helper"] == "rtsp" then
      port = s.dest_port
      return true
    end
  end)
  return port
end


function vodOngoing(dest_port)
  if not dest_port then
    return false
  end
  local match = "dport="..dest_port
  local conntrack = io.popen("conntrack -L 2>/dev/null")
  if not conntrack then
    return false
  end

  local vod_ongoing = false
  for line in conntrack:lines() do
    if line:find(match) then
      vod_ongoing = true
      break
    end
  end
  conntrack:close()
  return vod_ongoing
end

function wait()
  local port = vodPort()
  local blockOnVod = cursor:get("cwmpd", "cwmpd_config", "delay_upgrade_vod") == "1"
  while(callOngoing() or (blockOnVod and vodOngoing(port))) do
	  os.execute("sleep 5")
	end
end

wait()
