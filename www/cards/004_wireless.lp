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
  psk = "uci.wireless.wifi-ap.@ap0.wpa_psk_key",
  wep = "uci.wireless.wifi-ap.@ap0.wep_key",
  secmode = "uci.wireless.wifi-ap.@ap0.security_mode",
}
content_helper.getExactContent(content_wifi)
local content_wifi5 = {

  state5 = "uci.wireless.wifi-device.@radio_5G.state",
  ssid5 = "uci.wireless.wifi-iface.@wl1.ssid",
  psk5 = "uci.wireless.wifi-ap.@ap1.wpa_psk_key",
  wep5 = "uci.wireless.wifi-ap.@ap1.wep_key",
  secmode5 = "uci.wireless.wifi-ap.@ap1.security_mode",
}
content_helper.getExactContent(content_wifi5)

local wifistate = format(T"<strong>%s</strong> (2.4GHz)", content_wifi["ssid"])



local wifistateled = format("%s",content_wifi["state"])


local modalPath = "/modals/wireless-modal.lp"
local switchName = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/wireless-modal.lp") then
    switchName = "interface_enabled"
    
end
%>

<div class="span3">
  <div class="smallcard">

    <%=ui_helper.createCardHeader(T"Wireless", modalPath) %>

    <div class="content card_bg" data-bg-text="&#xf140;">
      <div class="divtable">
    <%
        local html = {}
        html[#html+1] = ui_helper.createSimpleLight(wifistateled, wifistate)
        if content_wifi5["state5"] ~= "" then
          local wifistate5= format(T"<strong>%s</strong> (5GHz)", content_wifi5["ssid5"])
          local wifistate5led = format("%s",content_wifi5["state5"])
          html[#html+1] = "<BR/>"
          html[#html+1] = ui_helper.createSimpleLight(wifistate5led, wifistate5)
        end
        ngx.print(html)
    %>
      </div>
    </div>
  </div>
</div>
