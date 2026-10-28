local dm = require("datamodel")
local inet = require("tch.inet")

--- match a given IP address to a given list of network interfaces
-- @tparam string ip the IP address string to test
-- @tparam table a list of network interface names to test
-- @return string the matching network interface name or nil plus error
--   message in case no match is found
local function match(ip, interfaces)
  if type(ip) == "string" and type(interfaces) == "table" then
    local param = (inet.isValidIPv4(ip) and "ipaddr") or (inet.isValidIPv6(ip) and "ip6addr")
    if param then
      for _, intf in pairs(interfaces) do
        local r = dm.get("rpc.network.interface.@" .. intf .. "." .. param) --ipaddr or ip6addr
        local thisip = r and r[1] and r[1].value
        if thisip and thisip:match(ip) then
          return intf
        end
      end
    end
  end
  return nil, "No given network interface matches the IP address"
end

return { match = match }
