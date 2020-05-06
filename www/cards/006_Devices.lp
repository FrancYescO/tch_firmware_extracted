<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local tonumber = tonumber

local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local format, find, sub = string.format, string.find, string.sub

-- Devices data
local devices_data = {
  numWireless = "sys.hosts.ActiveWirelessNumberOfEntries",
  numEthernet = "sys.hosts.ActiveEthernetNumberOfEntries",
}
content_helper.getExactContent(devices_data)

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/device-modal.lp") then
  modalPath = "/modals/device-modal.lp"
end
%>

<div class="span3">
  <div class="smallcard">
    <%= ui_helper.createCardHeader(T"Devices", modalPath, switchName, nil)  %>
    <div class="content">
      <%
        local nEth = tonumber(devices_data["numEthernet"]) or 0
        local nWiFi = tonumber(devices_data["numWireless"]) or 0

        local modal_link='class="modal-link" data-toggle="modal" data-remote="modals/device-modal.lp" data-id="device-modal"'
        ngx.print(
            '<p class="subinfos">',
            format( N('<strong id = "Ethernet_Devices" %1$s>%2$d ethernet device</strong> connected', 
                      '<strong id = "Ethernet_Devices" %1$s>%2$d ethernet devices</strong> connected', nEth), 
                      modal_link, nEth),
            '</p>',
            '<p class="subinfos">',
            format( N('<strong id = "Wifi_Devices" %1$s>%2$d WiFi device</strong> connected',
                      '<strong id = "Wifi_Devices" %1$s>%2$d WiFi devices</strong> connected', nWiFi), 
                      modal_link, nWiFi),
            '</p>'
        )              
      %>
    </div>
  </div>
</div>
