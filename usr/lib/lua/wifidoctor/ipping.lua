local proxy = require("datamodel")

function init()
  proxy.add("uci.ipping.", "wifidoctor")
end

function start_ping(mac_address, duration, packetsize)
  local ipaddress=""
  local address
  local hosts
  local timeout
  local rep
  local ps
  hosts=proxy.get("sys.hosts.host.")
  for i, host in pairs(hosts) do
    if host.param == "MACAddress" then
        if host.value:lower() == mac_address:lower() then
            ipaddress= proxy.get(host.path.."IPAddress")[1].value
            break
        end
    end
  end
  if ipaddress =="" then
     return 1
  end
  if string.find(ipaddress, "%s") ~= nil then
     ipaddress = string.match(ipaddress, "(.+)%s+.+")
  end
  timeout = tostring(duration+1)
  rep = tostring(duration)
  ps=tostring(packetsize)
  proxy.set({["uci.ipping.@wifidoctor.Timeout"]=timeout,
            ["uci.ipping.@wifidoctor.DataBlockSize"]=ps,
            ["uci.ipping.@wifidoctor.Host"]=ipaddress,
            ["uci.ipping.@wifidoctor.NumberOfRepetitions"]=rep,
            ["uci.ipping.@wifidoctor.DiagnosticsState"]="Requested"})
  proxy.apply()
  return 0
end
