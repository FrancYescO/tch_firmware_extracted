--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local insert, format = table.insert, string.format

local dhcpState_text = ""
local dhcpState

local mapParams = {
    dhcpState = "uci.dhcp.dhcp.@lan.ignore",
    localdevIP = "uci.network.interface.@lan.ipaddr",
    localdevmask = "uci.network.interface.@lan.netmask",
}
content_helper.getExactContent(mapParams)

if mapParams["dhcpState"] == "" or mapParams["dhcpState"] == "0" then
    dhcpState_text = T"DHCP enabled"
    dhcpState = "1"
else
    dhcpState_text = T"DHCP disabled"
    dhcpState = "0"
end

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/ethernet-modal.lp") then
    modalPath = "/modals/ethernet-modal.lp"
end
  ngx.print('\
<div class="span3">\
  <div class="smallcard">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"Local Network", modalPath, switchName, nil) ); ngx.print('\
\
    <div class="content">\
\
      ');  
        ngx.print(
            ui_helper.createSimpleLight(dhcpState, dhcpState_text, { light = { id =  "LAN_DHCP_LEDStatus" }, span = { id =  "LAN_DHCP_Status" } } ),
            '<p class="subinfos">',
            format(T'Gateway IP is <strong id="Gateway_Ip">%s</strong> and', mapParams["localdevIP"]),
            '<br/>',
            format(T'netmask is <strong id="Netmask_Ip">%s</strong>', mapParams["localdevmask"]),
            '</p>'
        )
        ngx.print('\
\
    </div>\
  </div>\
</div>\
'); 