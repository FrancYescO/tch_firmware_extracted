<%
-- Enable localization
gettext.textdomain('webui-core')

local tinsert, format = table.insert, string.format
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local content_wifi24G = {
  state = "uci.wireless.wifi-device.@radio_2G.state",
  ssid = "uci.wireless.wifi-iface.@wl0.ssid",
  psk = "uci.wireless.wifi-ap.@ap0.wpa_psk_key",
  wep = "uci.wireless.wifi-ap.@ap0.wep_key",
  secmode = "uci.wireless.wifi-ap.@ap0.security_mode",
}
content_helper.getExactContent(content_wifi24G)

local content_wifi5G = {
   state = "uci.wireless.wifi-device.@radio_5G.state",
   ssid = "uci.wireless.wifi-iface.@wl1.ssid",
   psk = "uci.wireless.wifi-ap.@ap1.wpa_psk_key",
   secmode = "uci.wireless.wifi-ap.@ap1.security_mode",
  }
content_helper.getExactContent(content_wifi5G)

local pass
local wifi_ssid = false
local wifi_state = "0"
if content_wifi24G["state"] == "0" and content_wifi5G["state"] == "1"  then
  if content_wifi5G["secmode"]:find("psk") then
     pass = content_wifi5G["psk"]
  end
  wifi_ssid = content_wifi5G["ssid"]
elseif content_wifi24G["state"] == "1" and content_wifi5G["state"] == "0" then
   if content_wifi24G["secmode"]:find("wep") then
     pass = content_wifi24G["wep"]
   elseif content_wifi24G["secmode"]:find("psk") then
     pass = content_wifi24G["psk"]
   end
   wifi_ssid = content_wifi24G["ssid"]
elseif content_wifi24G["state"] == "1" and content_wifi5G["state"] == "1" then
   wifi_ssid = format("%s<br/>%s", content_wifi24G["ssid"], content_wifi5G["ssid"])
end

local wifistate = T"WiFi disabled"
if content_wifi24G["state"] == "1" or content_wifi5G["state"] == "1" then
  wifistate = T"WiFi enabled"
  wifi_state = "1"
end

local modalPath = nil
local switchName = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/wireless-modal.lp") then
   switchName = "interface_enabled"
   modalPath = "/modals/wireless-modal.lp"
end

%>

<div class="span3">
  <div class="smallcard">

    <%=ui_helper.createCardHeader(T"Wireless", modalPath, switchName, wifi_state) %>

    <div class="content">

    <%
        local html = {
            ui_helper.createSimpleLight(wifi_state, wifistate),
            '<p class="subinfos">',
        }
        if wifi_ssid then
            tinsert(html, ' ')
            tinsert(html, format(T'Wireless network name is <br/><strong>%s</strong>', wifi_ssid))
        end
        if session:isdefaultuser() == false and pass then
            tinsert(html, ' ')
            tinsert(html, format(T'and password is <strong>%s</strong>', pass))
        end
        tinsert(html, "</p>")
        ngx.print(html)
    %>

    </div>
  </div>
</div>


