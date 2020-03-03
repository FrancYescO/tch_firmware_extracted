--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local tinsert, format = table.insert, string.format
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local content_wifi = {
  state = "uci.wireless.wifi-device.@radio_2G.state",
  ssid = "uci.wireless.wifi-iface.@wl0.ssid",
}
content_helper.getExactContent(content_wifi)

local content_wifi_5G = {
  state = "uci.wireless.wifi-device.@radio_5G.state",
  ssid = "uci.wireless.wifi-iface.@wl1.ssid",
}
content_helper.getExactContent(content_wifi_5G)

local wifistate, wifilight
if content_wifi["state"] == "1" or content_wifi_5G["state"] == "1" then
  wifistate = T"Wi-Fi enabled"
  wifilight = "1"
else
  wifistate = T"Wi-Fi disabled"
  wifilight = "0"
end

local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/wireless-modal.lp") then
    modalPath = "/modals/wireless-modal.lp"
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
\
    ');  ngx.print(ui_helper.createCardHeaderNoIcon(T"Wi-Fi", modalPath, nil, nil) ); ngx.print('\
\
    <div class="content">\
\
    ');  
        local ssid =""
        if content_wifi_5G["ssid"] ~= "" then
            ssid = format(T'Wi-Fi network name is <br/><strong>%s<br/>%s</strong>', content_wifi["ssid"] .. ' (2.4G)', content_wifi_5G["ssid"] .. ' (5G)')
        else
            ssid = format(T'Wi-Fi network name is <br/><strong>%s</strong>', content_wifi["ssid"] .. ' (2.4G)')
        end
        local html = {
            ui_helper.createSimpleLight(wifilight, wifistate),
            '<p class="subinfos">', ssid
        }
        tinsert(html, "</p>")
        ngx.print(html)
      ngx.print('\
\
    </div>\
  </div>\
</div>\
'); 