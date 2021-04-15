local require, ipairs, format = require, ipairs , string.format
local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local wanIntf = post_helper.getActiveInterface()
local wan6Intf = post_helper.getActiveInterface_v6()
local M = {}

-- check whether the router is in bridged mode
-- If no wan interface is configured then the router is in bridged mode.
function M.isBridgedMode()
  if (proxy.get("uci.network.interface.@"..wanIntf..".")) then
    return false
  end
  return true
end

function M.configBridgedMode()
  local success
  local ifnames = 'eth0 eth1 eth2 eth3 eth4 atm_8_35 ptm0'
  success = proxy.set({
    ["uci.wansensing.global.enable"] = '0',
    ["uci.network.interface.@lan.ifname"] = ifnames,
    ["uci.dhcp.dhcp.@lan.ignore"] = '1'
  })

  local delnames = {
    format("uci.network.interface.@%s.", wanIntf),
    format("uci.network.interface.@%s.", wan6Intf),
    "uci.network.interface.@wwan.",
    "uci.network.interface.@gt0.",
    "uci.network.interface.@hotspot.",
    "uci.network.interface.@lan.pppoerelay."
  }
  for _, intfs in ipairs(delnames) do
    proxy.del(intfs)
  end
  success = success and proxy.apply()
  return success
end

return M
