--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local insert, format = table.insert, string.format

local modalpath = "modals/ethernet-modal.lp"
local dhcpState_text = ""
local dhcpState

local mapParams = {
    dhcpv4State = "uci.dhcp.dhcp.@lan.dhcpv4",
    dhcpIgnore = "uci.dhcp.dhcp.@lan.ignore",
    localdevIP = "uci.network.interface.@lan.ipaddr",
    localdevmask = "uci.network.interface.@lan.netmask",
    localIPv6 = "uci.network.interface.@lan.ipv6",
    localIPv6Prefix = "rpc.network.interface.@lan.ip6prefix_assignment"
}
content_helper.getExactContent(mapParams)

if mapParams["dhcpIgnore"] == "1" or mapParams["dhcpv4State"] == "disabled" then
  dhcpState_text = T"DHCP Disabled"
  dhcpState = "0"
else
  dhcpState_text = T"DHCP Enabled"
  dhcpState = "1"
end
local LANv6 = "none"

if mapParams["localIPv6"] == "1" then
    LANv6 = "noprefix"
    if mapParams["localIPv6Prefix"] ~= "" then
      if string.match(mapParams["localIPv6Prefix"],"^fd") == "fd" or string.match(mapParams["localIPv6Prefix"],"^fc") == "fc" then
        LANv6 = "ula"
      else
        LANv6 = "prefix"
      end
    end
end

local ipv6_state_map = {
    none = T"IPv6 Disabled",
    noprefix = T"IPv6 Not Assigned",
    prefix = T"IPv6 Assigned",
    ula = T"IPv6 Private Only",
}

setmetatable(ipv6_state_map, untaint_mt)

local ipv6_light_map = {
    none = "off",
    noprefix = "orange",
    prefix = "green",
    ula = "orange",
}
setmetatable(ipv6_light_map, untaint_mt)

ngx.print('\
<div class="span3">\
  <div class="smallcard">',
    ui_helper.createCardHeader(T"Local Network", modalpath), '\
    <div class="content card_bg" data-bg-text="&#xf015;">\
      <div class="divtable">');
      local ipv6display = ""
      if LANv6 ~= "none" then 
        ipv6display = ui_helper.createSimpleLight(nil, ipv6_state_map[LANv6] or T"Unknown", { light = { class = ipv6_light_map[LANv6] or "red" } }) 
      end 
      ngx.print(
		ui_helper.createSimpleLight(dhcpState, dhcpState_text, { light = { id =  "LAN_DHCP_LEDStatus" }, span = { id =  "LAN_DHCP_Status" } } ),
		'<div class=\"subinfos\"><span>',T'Gateway',': </span><span><b>', mapParams["localdevIP"],'</b></span></div>',
		'<div class=\"subinfos\"><span>',T'Netmask',': </span><span><b>', mapParams["localdevmask"],'</b></span></div>',
		ipv6display,'\
      </div>\
    </div>\
  </div>\
</div>');
