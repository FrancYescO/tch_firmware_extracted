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
  secmode = "uci.wireless.wifi-ap.@ap0.security_mode",
  state_ap = "uci.wireless.wifi-ap.@ap0.state",
  bs = "uci.wireless.wifi-ap.@ap0.bandsteer_id"
}
content_helper.getExactContent(content_wifi)
local content_wifi5 = {

  state5 = "uci.wireless.wifi-device.@radio_5G.state",
  ssid5 = "uci.wireless.wifi-iface.@wl1.ssid",
  secmode5 = "uci.wireless.wifi-ap.@ap1.security_mode",
  state5_ap = "uci.wireless.wifi-ap.@ap1.state",
  bs = "uci.wireless.wifi-ap.@ap1.bandsteer_id"
}
content_helper.getExactContent(content_wifi5)

local wifistate = format(T"<strong>%s</strong> (2.4GHz)", content_wifi["ssid"])
local wifistate5



--local wifistateled = format("%s",content_wifi["state"])
local wifistateled = "0"
if content_wifi["state"] == "1" and content_wifi["state_ap"] == "1" then
    wifistateled = "1"
end
local modalPath = "/modals/wireless-modal.lp"






local wifistate5led = "0"
if content_wifi5["state5"] ~= "" then
          wifistate5 = format(T"<strong>%s</strong> (5GHz)", content_wifi5["ssid5"])
          if content_wifi5["state5"] == "1" and content_wifi5["state5_ap"] == "1" then
              wifistate5led = "1"
          end
end

local samessid = 0
if  content_wifi["ssid"] == content_wifi5["ssid5"] 
    and content_wifi["bs"] == "bs0" 
    and content_wifi5["bs"] == "bs0"
    and wifistateled == "1"
    and wifistate5led == "1" then
        samessid = 1
        wifistate = format(T"<strong>%s</strong>", content_wifi["ssid"])
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
        if samessid ~= 1 and content_wifi5["state5"] ~= "" then
            html[#html+1] = "<BR/>"
            html[#html+1] = ui_helper.createSimpleLight(wifistate5led, wifistate5)
            
        end
        
        if samessid == 1  then
          html[#html+1] = "<BR/>"
          html[#html+1] = format("<div class=\"subinfos\">%s</div>",T"Shared - Auto 5GHz")
        end
        
        

        
        
        ngx.print(html)
    %>
      </div>
    </div>
  </div>
</div>
