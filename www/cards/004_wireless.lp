<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local wifi24G = {
  state = "uci.wireless.wifi-device.@radio_2G.state",
  ssid = "uci.wireless.wifi-iface.@wl0.ssid",
  psk = "uci.wireless.wifi-ap.@ap0.wpa_psk_key",
  wep = "uci.wireless.wifi-ap.@ap0.wep_key",
  secmode = "uci.wireless.wifi-ap.@ap0.security_mode",
}
content_helper.getExactContent(wifi24G)

-- note: on boards without 5Ghz the getExactContent() call
-- will result in an empty table!
local wifi5G = {
  state = "uci.wireless.wifi-device.@radio_5G.state",
  ssid = "uci.wireless.wifi-iface.@wl1.ssid",
  psk = "uci.wireless.wifi-ap.@ap1.wpa_psk_key",
  secmode = "uci.wireless.wifi-ap.@ap1.security_mode",
}
content_helper.getExactContent(wifi5G)

local pass
local wifi_ssid = {}
local wifi_state = "0"
local wifistate = T"WiFi disabled"

if wifi24G.state == "1" then
  wifi_ssid[#wifi_ssid+1] = wifi24G.ssid
  wifistate = T"WiFi enabled"
  wifi_state = "1"
  if wifi5G.state ~= "1" then
    if wifi24G.secmode:find("wep") then
      pass = wifi24G.wep
    elseif wifi24G.secmode:find("psk") then
      pass = wifi24G.psk
    end
  end
end
if wifi5G.state == "1" then
  wifi_ssid[#wifi_ssid+1] = wifi5G.ssid
  wifistate = T"WiFi enabled"
  wifi_state = "1"
  if wifi24G.state ~= "1" then
    if wifi5G.secmode:find("psk") then
      pass = wifi5G.psk
    end
  end
end

local modalPath
local switchName
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
    if #wifi_ssid == 1 then
      html[#html+1] = format(T'Network name is <br/><strong>%s</strong>', wifi_ssid[1])
    elseif #wifi_ssid == 2 then
      html[#html+1] = format(T'Network names are <br/><strong>%s</strong><br/><strong>%s</strong>',
        wifi_ssid[1], wifi_ssid[2])
    end

--[[    if pass and not session:isdefaultuser() then
      html[#html+1] = "<br/>"
      html[#html+1] = format(T'Password is <strong>%s</strong>', pass)
    end
]]


    html[#html+1] = "</p>"
    ngx.print(html)
%>
    </div>
  </div>
</div>
