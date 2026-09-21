
local pairs = pairs

local function load(ubus)
  local entries = {}
  local data = {}
  local devices = ubus:call("hostmanager.device", "get", {}) or {}
  for _, device in pairs(devices) do
    local MAC = device["mac-address"]
    for _, ip in pairs(device.ipv4 or {}) do
      local address = (ip.state=="connected") and ip.address
      if address then
        local key = address:gsub("%.", "_")
        entries[#entries+1] = key
        data[key] = {MAC=MAC, IPv4=address}
      end
    end
  end
  return entries, data
end

return {
  load = load
}
