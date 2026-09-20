<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local tonumber = tonumber

local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

-- Devices data
local devices_data = {
  numWireless = "sys.hosts.WirelessNumberOfEntries",
  numEthernet = "sys.hosts.EthernetNumberOfEntries",
}
content_helper.getExactContent(devices_data)

local session = ngx.ctx.session
if session:hasAccess("/modals/device-modal.lp") then
%>

<div class="span3">
  <div class="smallcard">
    <%= ui_helper.createCardHeaderNoIcon(T"Devices", "modals/device-modal.lp")  %>
    <div class="content">
      <%
        local nEth = tonumber(devices_data["numEthernet"]) or 0
        local nWiFi = tonumber(devices_data["numWireless"]) or 0
        local modal_link='class="modal-link" data-toggle="modal" data-remote="modals/device-modal.lp" data-id="device-modal"'
        ngx.print(
            '<p class="subinfos">',
            format( N('<strong %1$s>%2$d ethernet device</strong> connected',
                      '<strong %1$s>%2$d ethernet devices</strong> connected', nEth),
                      modal_link, nEth),
            '</p>',
            '<p class="subinfos">',
            format( N('<strong %1$s>%2$d Wi-Fi device</strong> connected',
                      '<strong %1$s>%2$d Wi-Fi devices</strong> connected', nWiFi),
                      modal_link, nWiFi),
            '</p>'
        )
      %>
    </div>
  </div>
</div>
<%
end
%>
