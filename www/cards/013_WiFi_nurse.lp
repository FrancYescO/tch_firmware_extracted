--pretranslated: do not change this file
 
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
}
content_helper.getExactContent(devices_data)

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/wifi-nurse-modal.lp") then
  modalPath = "/modals/wifi-nurse-modal.lp"
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"WiFi Nurse", modalPath, switchName, nil)  ); ngx.print('\
    <div class="content">\
      ');  
        local nWiFi = tonumber(devices_data["numWireless"]) or 0

        local modal_link='class="modal-link" data-toggle="modal" data-remote="modals/wifi-nurse-modal.lp" data-id="wifi-nurse-modal"'
        ngx.print(
            '<p class="subinfos">',
            format( N('<strong id = "Wifi_Devices" %1$s>%2$d WiFi device</strong> connected',
                      '<strong id = "Wifi_Devices" %1$s>%2$d WiFi devices</strong> connected', nWiFi),
                      modal_link, nWiFi),
            '</p>'
        )
        ngx.print('\
    </div>\
  </div>\
</div>\
'); 