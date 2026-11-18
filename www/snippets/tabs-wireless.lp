--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  
gettext.textdomain('webui-core')
local ipairs, string = ipairs, string
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local variant_helper = require("variant_helper")
local proxy = require("datamodel")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "tabs")
local variantHelperStation = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local items = {}
local smartWifiStatus = proxy.get("rpc.wireless.SmartWiFi.Active")
smartWifiStatus = smartWifiStatus and smartWifiStatus[1] and smartWifiStatus[1].value or ""

local isNewLayout = proxy.get("uci.env.var.em_new_ui_layout")
isNewLayout = isNewLayout and isNewLayout[1].value or "0"

if isNewLayout == "1" then
  items = {
    {"wireless-radio-modal-newEM.lp", T"Radio"},
  }
  local endpoint_profile = proxy.getPN("uci.wireless.wifi-ep.", true)
  if endpoint_profile then
    local wifiEP = "uci.wireless.wifi-ep."
    local availableEPIntf = content_helper.convertResultToObject(wifiEP .. "@.", proxy.get(wifiEP))
    local epIntfIface, mode
    for _, v in ipairs(availableEPIntf) do
      epIntfIface = v.iface
      mode = proxy.get("uci.wireless.wifi-iface.@"..epIntfIface..".mode") and proxy.get("uci.wireless.wifi-iface.@"..epIntfIface..".mode")[1].value
    end
    if mode == "sta" and post_helper.getVariantValue(variantHelperStation, "stationTab") then
      items[#items + 1] = {"wireless-station-modal-newEM.lp", T"Station"}
    end
  end
  items[#items + 1] = {"wireless-ap-modal-newEM.lp", T"AP"}
  items[#items + 1] = {"wireless-wps-modal-newEM.lp", T"WPS"}
  items[#items + 1] = {"tod_wireless-modal-newEM.lp", T"Wireless Control"}
  if smartWifiStatus == "" or smartWifiStatus == "0" then
    items[#items + 1] = {"wireless-client-modal.lp", T"Client Monitoring"}
  end
else
  if post_helper.getVariantValue(variantHelper, "wifiNurse") then
    items = {
      {"wireless-modal.lp", T"Wireless "},
      {"tod_wireless-modal.lp", T"Wireless Control"},
      {"wifi-nurse-modal.lp", T"Wifi Nurse"}
    }
  else
    items = {
      {"wireless-modal.lp", T"Wireless "},
      {"tod_wireless-modal.lp", T"Wireless Control"}
    }
  end
end

local tabs = {}
local session = ngx.ctx.session

for _,value_items in pairs(items) do
  if session:hasAccess("/modals/" .. value_items[1]) then
    tabs[#tabs+1] = value_items
  end
end

local html = {}

local uri = ngx.var.uri

for _,value_tabs in ipairs(tabs) do
  local active = ""
    if uri == ("/modals/" .. value_tabs[1]) then
      active = "active"
    end

    html[#html+1] = string.format('<li class="%s"><a id ="%s" href="#" data-remote="/modals/%s">%s</a></li>', active, value_tabs[2], value_tabs[1], value_tabs[2])
end
ngx.print(html)

  ngx.print('\
\
</ul>\
'); 