--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ipairs, ngx, string = ipairs, ngx, string
local format, match = string.format, string.match
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local wirelessSSID_helper = require("wirelessSSID_helper")
local modalPath
local session = ngx.ctx.session
if session:hasAccess("/modals/wireless-modal.lp") then
  modalPath = "/modals/wireless-modal.lp"
elseif not session:isdefaultuser() then
  return
end
local ssid_list = wirelessSSID_helper.getSSID()
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print(ui_helper.createCardHeader(T"Wireless", modalPath, nil, nil) ); ngx.print('\
    <div class="content">\
');  

for i,v in ipairs(ssid_list) do
  if i <= 4  then 
  local status_led = v.state == "1" and "light green" or" light off"   ngx.print('\
  <div class ="');  ngx.print(status_led); ngx.print('"></div>\
   <p id = \'wificard_');  ngx.print(i); ngx.print('\' class="wifi-card"><strong>');  ngx.print(v.ssid); ngx.print('</strong>(');  ngx.print(v.radio); ngx.print(')</p>\
  ');  else  ngx.print('\
    <p id = \'wificard_');  ngx.print(i); ngx.print('\' class="wifi-card"><strong style="margin-left:26px;font-size:30px;">...</strong></p>\
  ');  end
end  ngx.print('\
    </div>\
  </div>\
</div>\
<script>\
  $(document).ready(function() {\
    var self = this;\
    self.render = function() {\
      $.post("/ajax/wirelesscard.lua?auto_update=true", [tch.elementCSRFtoken()], function(data) {\
        if (data != "") {\
          if (data.length > 4) {\
            $(".wifi-card strong").attr("style", "margin-left:26px;font-size:30px;").html("...");\
            clearInterval(refreshTimer);\
          }\
          for (i = 0; i <=3 ; i++) {\
            var status_light =  ((data[i].listatus == "light green" || data[i].listatus == "light off")) ? "<strong>"+data[i].ssid+"</strong>" : "<strong>Fetching 5GHz SSID </strong><br>Please wait";\
            $("wificard_"+(i+1)).html("<div class=\'" + data[i].listatus + "\'></div><p class = \'wifi-card\'>"+status_light+"</p>");\
              clearInterval(refreshTimer);\
            }\
          }\
         else {\
          clearInterval(refreshTimer);\
        }\
      }, "json");\
    };\
    var refreshTimer = setInterval(self.render, 7000);\
    self.render();\
  });\
</script>\
'); 