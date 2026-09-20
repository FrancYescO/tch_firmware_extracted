<%
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

local wifistate
if content_wifi["state"] == "1" or content_wifi_5G["state"] == "1" then
  wifistate = T"Wi-Fi enabled"
else
  wifistate = T"Wi-Fi disabled"
end

local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/wireless-modal.lp") then
    modalPath = "/modals/wireless-modal.lp"
end
%>

<div class="span3">
  <div class="smallcard">

    <%=ui_helper.createCardHeaderNoIcon(T"Wireless", modalPath, nil, nil) %>

    <div class="content">

    <%
        local ssid =""
        if content_wifi_5G["ssid"] ~= "" then
            ssid = format(T'Wireless network name is <strong>%s %s</strong>', content_wifi["ssid"], content_wifi_5G["ssid"])
        else
            ssid = format(T'Wireless network name is <strong>%s</strong>', content_wifi["ssid"])
        end
        local html = {
            ui_helper.createSimpleLight(content_wifi["state"], wifistate),
            '<p class="subinfos">', ssid
        }
        tinsert(html, "</p>")
        ngx.print(html)
    %>

    </div>
  </div>
</div>
