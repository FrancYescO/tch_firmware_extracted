--pretranslated: do not change this file
 
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local untaint = string.untaint
local session = ngx.ctx.session
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local pairs = pairs
local match, format, upper = string.match, string.format, string.upper

local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local validateBoolean = post_helper.validateBoolean

local wifiEP = "uci.wireless.wifi-ep."
local availableEPIntf = content_helper.convertResultToObject(wifiEP .. "@.", proxy.get(wifiEP))
local wifiEPPath = "uci.wireless.wifi-ep-profile."
local availableEP = content_helper.convertResultToObject(wifiEPPath .."@.", proxy.get(wifiEPPath))

--Get the wifi-ep and wifi-ep-profile path values
local epIntfRadio, epIntfIface
local epProfileIndex, epIndex, frequencyList = {}, {}, {}
for _, v in ipairs(availableEPIntf) do
   epIndex[#epIndex + 1] = v.paramindex
   epIntfIface = v.iface
   frequencyVal = proxy.get("uci.wireless.wifi-iface."..epIntfIface..".device") and proxy.get("uci.wireless.wifi-iface."..epIntfIface..".device")[1].value
   if frequencyVal == "radio_2G" then
     frequencyList[v.paramindex] = "2 GHz"
   else
     frequencyList[v.paramindex] = "5 GHz"
   end
end
for _, intf in ipairs(availableEP) do
  epProfileIndex[#epProfileIndex + 1] = intf.paramindex
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "wps_pbc" then
    proxy.set("rpc.wireless.wps_button", "1")
    proxy.apply()
end
local wps_button_handler = setmetatable({
  ["1"] = "wps_button_pressed.sh",
  ["0"] = "acl_button_pressed.sh"
}, untaint_mt)

local content = {}

for _, intf in ipairs(epIndex) do
  content["admin_state"..intf] = format("rpc.wireless.station.@%s.state", intf)
  content["connected_state"..intf] = format("rpc.wireless.station.@%s.status", intf)
  content["rssi"..intf] = format("rpc.wireless.station.@%s.rssi", intf)
end
for _, epProfile in ipairs(epProfileIndex) do
  content["ssid"..epProfile] = format("uci.wireless.wifi-ep-profile.@%s.ssid", epProfile)
  content["security"..epProfile] = format("uci.wireless.wifi-ep-profile.@%s.security_mode", epProfile)
  content["wpa_psk"..epProfile] = format("uci.wireless.wifi-ep-profile.@%s.wpa_psk_key", epProfile)
end
local mapParams = {
  wps_button_handler = wpshandler_data and "uci.button.button.@wps.handler"
}
local mapValid = {
  wps_button_handler = function(val, object)
    object["wps_button_handler"] = wps_button_handler["1"]
    return true
  end
}

content_helper.getExactContent(content)

ngx.print(ui_helper.createHeader(T"Wireless", false, false))   ngx.print('\
<div class="modal-body update">\
  ');  local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-wireless.lp")
    ngx.print('\
  <form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
    <div class = "span6">\
      ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      local html = {}
      local stateClass = {
        switch = {
        }
      }
      local labelclass = {
        input = {
          maxlength= "32",
          class= "span4",
        }
      }
      local secattributes = {
        group = {
          class = "",
        },
        select = {
          class = "monitor-changes"
        }
      }
      for _, intf in ipairs(epIndex) do
        html[#html + 1] = "<fieldset>"
        html[#html + 1] = "<legend>"
        html[#html + 1] = frequencyList[intf]
        html[#html + 1] = [[</legend>]]
        html[#html + 1] = ui_helper.createLabel(T"State", content["admin_state"..intf] == "1" and T"On" or T"Off", stateClass)
        html[#html + 1] = ui_helper.createLabel(T"Status", content["connected_state"..intf] == "1" and T"Connected" or T"Disconnected", labelclass)
        html[#html + 1] = ui_helper.createLabel(T"RSSI", content["rssi"..intf] .. " dBm", labelclass)
        for _, epProfile in ipairs(epProfileIndex) do
          if string.match(epProfile, intf) then
            html[#html + 1] = ui_helper.createLabel(T"SSID", content["ssid"..epProfile] , labelclass)
            if(content["security"..epProfile] ~= "none") then
              html[#html + 1] = ui_helper.createLabel(T"Password", content["wpa_psk"..epProfile], labelclass)
            end
            html[#html + 1] = ui_helper.createLabel(T"Security Mode", content["security"..epProfile] == "none" and "None" or upper(content["security"..epProfile]), secattributes)
          end
        end
      end
      local wps_class = {
        switch = {
          class = "wpsclass"
        },
        button = {
          ["data-name"] = "action",
          ["data-value"] = "wps_pbc",
        }
      }
      html[#html + 1] = ui_helper.createButton(T"WPS PBC", T"Trigger", "icon-refresh", wps_class)
      ngx.print(html)
        ngx.print('\
    </div>\
  </form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 