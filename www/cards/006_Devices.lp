--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local tonumber = tonumber

local lfs = require("lfs")
local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local format, find, sub, match = string.format, string.find, string.sub, string.match

-- Devices data
local devices_data = {
  numWireless = "sys.hosts.ActiveWirelessNumberOfEntries",
  numEthernet = "sys.hosts.ActiveEthernetNumberOfEntries",
}
content_helper.getExactContent(devices_data)

  modalPath = "/modals/device-modal.lp"
  modal_link='class="modal-link" data-toggle="modal" data-remote="modals/device-modal.lp" data-id="device-modal"'

local session = ngx.ctx.session  
local proxy = require("datamodel")
local tod_count = proxy.getPN("uci.tod.host.", true)
tod_count = tod_count and #tod_count or 0

ngx.print('\
\
<div class="span3">\
  <div class="smallcard">',
    ui_helper.createCardHeader(T"Devices", modalPath), '\
    <div class="content card_bg" data-bg-text="&#xf108;">\
      <div class="divtable">');
        local nEth = tonumber(devices_data["numEthernet"]) or 0
        local nWiFi = tonumber(devices_data["numWireless"]) or 0
        ngx.print('<p class="subinfos">',
            format( N('<strong id = "Ethernet_Devices" %1$s>%2$d Ethernet Device</strong> Connected', 
                      '<strong id = "Ethernet_Devices" %1$s>%2$d Ethernet Devices</strong> Connected', nEth), 
                      modal_link, nEth),
            '</p>\
            <p class="subinfos">',
            format( N('<strong id = "Wifi_Devices" %1$s>%2$d WiFi Device</strong> Connected',
                      '<strong id = "Wifi_Devices"  %1$s>%2$d WiFi Devices</strong> Connected', nWiFi), 
                      modal_link, nWiFi),
            '</p>');
            if session:hasAccess("/modals/tod-modal.lp") then
            modal_link = 'class="modal-link" id = "Site_Blocking_Count" data-toggle="modal" data-remote="modals/tod-modal.lp" data-id="tod-modal"'

	          ngx.print('\
            <p class="subinfos">',
            format( N('<strong %1$s>%2$d ToD</strong> Rule',
                      '<strong id="ToD Rules" %1$s>%2$d ToD</strong> Rules', tod_count),
                      modal_link, tod_count), '\
            </p>');
            end
            ngx.print('\
      </div>\
    </div>\
  </div>\
</div>');

