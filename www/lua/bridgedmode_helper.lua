local require, ipairs = require, ipairs
local proxy = require("datamodel")
local M = {}

-- check whether the router is in bridged mode
-- If no wan interface is configured then the router is in bridged mode.
function M.isBridgedMode()
  if (proxy.get("uci.network.interface.@wan.")) then
    return false
  end
  return true
end

function M.configBridgedMode(vdslvid, ethvid)
  local vdsl_port = vdslvid == "0" and "ptm0" or "vlanptm0"
  local eth_port = ethvid == "0" and "eth4" or "vlanwan"
  local ifnames = "eth0 eth1 eth2 atm_wan " .. vdsl_port .. " " .. eth_port
  local success = proxy.set({
    ["uci.wansensing.global.enable"] = '0',
    ["uci.intercept.config.enabled"] = '0',
    ["uci.network.interface.@wan.ifname"] = ifnames,
    ["uci.network.interface.@wan.proto"] = "static",
    ["uci.network.interface.@wan.type"] = "bridge",
    ["uci.network.interface.@wan.auto"] = '1',
    ["uci.dhcp.dhcp.@lan.ignore"] = '1',
    ["uci.dhcp.dhcp.@wan.ignore"] = ''
  })

  local delnames = {
    "uci.network.interface.@wan6.",
    "uci.network.interface.@wwan.",
    "uci.network.interface.@lan.pppoerelay."
  }

  for _, intfs in ipairs(delnames) do
    proxy.del(intfs)
  end

  success = success and proxy.apply()
  return success
end

return M
