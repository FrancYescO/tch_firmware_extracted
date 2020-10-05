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

-- see if the file exists
function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

function vodOngoing(file)
  local vod_ongoing = false
  if not file_exists(file) then return false end
      cursor:foreach("firewall", "helper", function(s)
      if s["helper"] == "rtsp" then
          for line in io.lines(file) do
              if string.find(line, "dport=" .. s["dest_port"]) ~= nil then
                  vod_ongoing = true
                  return true
              end
          end
      end
  end)
  return vod_ongoing
end

while(callOngoing() or ((cursor:get("cwmpd", "cwmpd_config", "delay_upgrade_vod") == "1") and vodOngoing("/proc/net/nf_conntrack"))) do
	os.execute("sleep 5")
end
