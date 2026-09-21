local ubus = require("ubus")
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

while(callOngoing()) do
	os.execute("sleep 5")
end
