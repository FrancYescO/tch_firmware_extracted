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

%>

<div class="span3">
  <div class="smallcard">
    <%= ui_helper.createCardHeader(T"Devices", "modals/device-modal.lp")  %>
    <div class="content card_bg" data-bg-text="&#xf108;">
      <div class="divtable">   
      <%
        local nEth = tonumber(devices_data["numEthernet"]) or 0
        local nWiFi = tonumber(devices_data["numWireless"]) or 0

        local modal_link='class="modal-link" data-toggle="modal" data-remote="modals/device-modal.lp" data-id="device-modal"'
        ngx.print(
            '<p class="subinfos">',
            format( N('<strong id = "Ethernet_Devices" %1$s>%2$d Ethernet Device</strong> Connected', 
                      '<strong id = "Ethernet_Devices" %1$s>%2$d Ethernet Devices</strong> Connected', nEth), 
                      modal_link, nEth),
            '</p>',
            '<p class="subinfos">',
            format( N('<strong id = "Wifi_Devices" %1$s>%2$d WiFi Device</strong> Connected',
                      '<strong id = "Wifi_Devices"  %1$s>%2$d WiFi Devices</strong> Connected', nWiFi), 
                      modal_link, nWiFi),
            '</p>'
        )              
      %>
      </div>
    </div>
  </div>
</div>

