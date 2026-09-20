<%
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local insert, format = table.insert, string.format
local session = ngx.ctx.session
if session:hasAccess("/modals/ethernet-modal.lp") then

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

%>
<div class="span3">
  <div class="smallcard">

    <%= ui_helper.createCardHeaderNoIcon(T"Local Network", "modals/ethernet-modal.lp") %>

    <div class="content">

      <%
        ngx.print(
            ui_helper.createSimpleLight(dhcpState, dhcpState_text),
            '<p class="subinfos">',
            format(T'Gateway IP is <strong>%s</strong> and netmask is <strong>%s</strong>', mapParams["localdevIP"], mapParams["localdevmask"]),
            '</p>'
        )
      %>

    </div>
  </div>
</div>
<%
end
%>
