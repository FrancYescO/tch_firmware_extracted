local require, ipairs, format = require, ipairs , string.format
local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local wanIntf = post_helper.getActiveInterface()
local wan6Intf = post_helper.getActiveInterface_v6()
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "InternetCard", "card")
local M = {}

-- check whether the router is in bridged mode
-- If no wan interface is configured then the router is in bridged mode.
function M.isBridgedMode()
  if post_helper.getVariantValue(variantHelper, "fullBridge") then
    if (proxy.get("uci.env.var.bridgemode")[1].value == "1") then
      return true
    else
      return false
    end
  elseif (proxy.get("uci.network.interface.@"..wanIntf..".")) then
    return false
  end
  return true
end

function M.configBridgedMode()
  local success
  local ifnames = proxy.get("uci.network.interface.@lan.ifname")
  local wanifnames = " atm_8_35 ptm0 veip0_1"
  ifnames = ifnames[1].value  .. wanifnames

  success = proxy.set({
    ["uci.wansensing.global.enable"] = '0',
    ["uci.network.interface.@lan.ifname"] = ifnames,
    ["uci.dhcp.dhcp.@lan.ignore"] = '1',
    ["uci.gponl3.interface.@veip0_1.mode"] = 'bridged'
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
