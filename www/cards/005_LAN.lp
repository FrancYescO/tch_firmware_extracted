--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local variant_helper = require("variant_helper")
local format = string.format
local dhcpStateText, dhcpState

local mapParams = {
  dhcpv4State = "uci.dhcp.dhcp.@lan.dhcpv4",
  dhcpIgnore = "uci.dhcp.dhcp.@lan.ignore",
  localdevIP = "uci.network.interface.@lan.ipaddr",
  localdevmask = "uci.network.interface.@lan.netmask",
  dhcpv6State = "uci.dhcp.dhcp.@lan.dhcpv6",
  raState = "uci.dhcp.dhcp.@lan.ra",
  localIPv6Prefix = "rpc.network.interface.@lan.ip6prefix_assignment"
}
content_helper.getExactContent(mapParams)

dhcpStateText = (mapParams.dhcpIgnore == "1" or mapParams.dhcpv4State == "disabled") and T"DHCP disabled" or T"DHCP enabled"
dhcpState = dhcpStateText == T"DHCP disabled" and "0" or "1"

local LANv6 = "none"
if mapParams.dhcpv6State == "server" and mapParams.raState == "server" then
  LANv6 = mapParams.localIPv6Prefix ~= "" and "prefix" or "noprefix"
end

local ipv6StateMap = {
  none = T"IPv6 Disabled",
  noprefix = T"IPv6 Not Assigned",
  prefix = T"IPv6 Assigned"
}
setmetatable(ipv6StateMap, untaint_mt)

local ipv6LightMap = {
  none = "off",
  noprefix = "orange",
  prefix = "green"
}
setmetatable(ipv6LightMap, untaint_mt)

local modalPath, switchName
local session = ngx.ctx.session
local role = session:getrole()
local usersValue = session:getusername()
local cardHelper = post_helper.getVariant(variant_helper, "CardView", "card")
local cardViewGFR = post_helper.getVariantValue(cardHelper, "cardViewGFR")

if not cardViewGFR or usersValue ~= 'assist' and cardViewGFR then
  if session:hasAccess("/modals/ethernet-modal.lp") then
    modalPath = "/modals/ethernet-modal.lp"
  elseif not session:isdefaultuser() then
    return
  end
end
  ngx.print('\
<div class = "span3">\
  <div class = "smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Local Network", modalPath, switchName, nil) ); ngx.print('\
    ');  if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
      <div class = "content">\
    ');  else   ngx.print('\
      <div class="content card_bg" data-bg-text="&#xf015;">\
    ');  end
      ngx.print(
        ui_helper.createSimpleLight(dhcpState, dhcpStateText, { light = { id =  "LAN_DHCP_LEDStatus" }, span = { id =  "LAN_DHCP_Status" } } ),
        '<p class="subinfos">',
        format(T'Gateway IP is <strong id="Gateway_Ip">%s</strong> and netmask is <strong id="Netmask_Ip">%s</strong>', mapParams["localdevIP"], mapParams["localdevmask"]),
        '</p>',
        ui_helper.createSimpleLight(nil, ipv6StateMap[LANv6] or T"Unknown", { light = { class = ipv6LightMap[LANv6] or "red" } })
        )
        ngx.print('\
    </div>\
  </div>\
</div>\
'); 