--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")
local variant_helper = require("variant_helper")
local format = string.format
local wanIntf = post_helper.getActiveInterface()
local variantHelper = post_helper.getVariant(variant_helper, "InternetCard", "card")
local nwcommon = require("transformer.mapper.nwcommon")
local proxy = require("datamodel")

local netMask = tonumber(proxy.get(format("rpc.network.interface.@%s.ipmask", wanIntf))[1].value)
local netMaskIp = netMask ~= "" and nwcommon.netmask2mask(netMask) or ""

-- Non-configurable data
local cs = {}
if post_helper.isFeatureEnabled("internetmodeHelper", role) then
  cs = {
    uci_wan_auto = format("uci.network.interface.@%s.auto", wanIntf),
    ipaddr = format("rpc.network.interface.@%s.ipaddr", wanIntf)
  }
else
  local interface_name = session:retrieve("network_interface_name") or wanIntf
  cs = {
    uci_wan_auto = format("uci.network.interface.@%s.auto",interface_name),
    ipaddr = format("rpc.network.interface.@%s.ipaddr",interface_name),
  }
end
content_helper.getExactContent(cs)

-- Figure out interface state
local static_state = "disabled"
local static_state_map = {
    disabled = T"Static disabled",
    connected = T"Static on",
}

local static_light_map = {
  disabled = "off",
  connected = "green",
}

if cs["uci_wan_auto"] ~= "0" and cs["ipaddr"]:len() > 0 then
    cs["uci_wan_auto"] = "1"
    static_state = "connected"
end

local modalPath = nil

local session = ngx.ctx.session
local usersValue = session:getusername()
local variantHelper = post_helper.getVariant(variant_helper, "InternetCard", "card")
local readOnlyInternetCard = post_helper.getVariantValue(variantHelper, "readOnlyInternetCard")

if not readOnlyInternetCard or usersValue ~= 'assist' and readOnlyInternetCard then
  if session:hasAccess("/modals/internet-modal.lp") then
    modalPath = "/modals/internet-modal.lp"
  end
end

  ngx.print('\
');  if post_helper.isFeatureEnabled("internetmodeHelper", role) then   ngx.print('\
  ');  ngx.print( ui_helper.createCardHeader(T"Internet Access", modalPath, nil, nil) ); ngx.print('\
');  end
if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
  <div class="content">\
');  else   ngx.print('\
  <div class="content card_bg" data-bg-text="&#xf0ec;">\
');  end   ngx.print('\
  ');  ngx.print( ui_helper.createSimpleLight(nil, static_state_map[static_state], { light = { class = static_light_map[static_state] } }) ); ngx.print('\
  <p class="subinfos">\
     ');  if static_state == "connected" then
            if post_helper.getVariantValue(variantHelper, "netMask") and netMaskIp ~= "" then
              ngx.print(format(T'WAN IP is <strong id ="wan_ip">%s</strong> and netmask is <strong id ="net_mask">%s</strong>', cs["ipaddr"], netMaskIp))
            else
              ngx.print(format(T'WAN IP is <strong>%s</strong>', cs["ipaddr"]))
            end
        end
       ngx.print('\
  </p>\
</div>\
'); 