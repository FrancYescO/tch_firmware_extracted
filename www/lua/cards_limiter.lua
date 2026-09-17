local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local wanIntf = post_helper.getActiveInterface()
local wan6Intf = post_helper.getActiveInterface_v6()
local M = {}
local proxy = require("datamodel")
local bridged = require("bridgedmode_helper")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "GatewayPage", "gateway")
local variantHelperInternet = post_helper.getVariant(variant_helper, "InternetCard", "card")
local bridge_limit_list = {}
local isNewLayout = proxy.get("uci.env.var.em_new_ui_layout")
isNewLayout = isNewLayout and isNewLayout[1].value or "0"
local extender_list = {}

if post_helper.getVariantValue(variantHelperInternet, "fullBridge") then
  bridge_limit_list = {
    ["system-info.lp"] = true,
    ["internet.lp"] = true,
    ["assistance.lp"] = true
  }
else
  bridge_limit_list = {
    ["system-info.lp"] = true,
    ["broadband.lp"] = true,
    ["wireless.lp"] = true,
    ["LAN.lp"] = true,
    ["usermgr.lp"] = true
  }
end

if post_helper.getVariantValue(variantHelper, "showSmartHomeCard") then
  bridge_limit_list["smartHome.lp"] = true
end

local lte_exclude_list = {
  ["broadband.lp"] = true,
  ["internet.lp"] = true
}

local easymesh_list = {
 ["wifiExtender.lp"] = true
}


extender_list = {
  ["system-info.lp"] = true,
  ["wireless.lp"] = true,
  ["diagnostics.lp"] = true,
  ["wifiExtender.lp"] = true,
  ["cwmpconf.lp"] = true,
  ["usermgr.lp"] = true
}

if isNewLayout == "1" then
  extender_list["wireless-newEM.lp"] = true
  extender_list["wireless.lp"] = false
end

function M.get_limit_info()
  local isLTEBoard = false
  local interfaces = {
    wan_proto = string.format("uci.network.interface.@%s.proto", wanIntf),
    wwan_proto = "uci.network.interface.@wwan.proto",
    wan6_proto = string.format("uci.network.interface.@%s.proto", wan6Intf),
  }
  content_helper.getExactContent(interfaces)
  if interfaces.wan_proto == 'mobiled' and
     interfaces.wwan_proto == 'mobiled' and
     interfaces.wan6_proto == 'mobiled' then
     isLTEBoard = true
  end
  local prod_name = proxy.get("uci.version.version.@version[0].product")
  prod_name = prod_name and prod_name[1].value
  if prod_name and prod_name:match(".*_extender.*") then
      return { isExtender = true }
  end
  local smartWifiStatus = proxy.get("rpc.wireless.SmartWiFi.Active")
  smartWifiStatus = smartWifiStatus and smartWifiStatus[1] and smartWifiStatus[1].value or ""
  if smartWifiStatus == "1" then
    return { smartwifistate = true }
  end
  if bridged.isBridgedMode() then
    return {bridged = bridged.isBridgedMode()}
  end
  return {isLTEBoard = isLTEBoard}
end

function M.card_limited(info, cardname)
  if info.isLTEBoard then
    return lte_exclude_list[cardname]
  end
  if info.bridged then
    return not bridge_limit_list[cardname]
  end
  if info.isExtender then
    return not extender_list[cardname]
  end
  if info.smartwifistate  then
    return easymesh_list[cardname]
  end
  return false
end

return M
