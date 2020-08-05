--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format

local stats = {
    link = "sys.eth.port.@eth4.status",
    mode = "sys.eth.port.@eth4.mode",
    speed = "sys.eth.port.@eth4.speed",

}
content_helper.getExactContent(stats)

-- Figure out interface state
local intf_state = "Disabled"
local intf_state_map = {
    Disabled = T"Ethernet Down",
    Connected = T"Ethernet Connected",
    Disconnected = T"Ethernet Not Connected",
}

local intf_light_map = {
  Disabled = "off",
  Disconnected = "red",
  Connected = "green",
}

if stats.link == "up" then
    intf_state = "Connected"
else
    intf_state = "Disconnected"
end

 
ngx.print('\
<fieldset>\
  <legend>', T"Physical Link Status", '</legend>');
    local html = {}
    -- Label that shows Ethernet status
    html[#html + 1] = ui_helper.createLight(T"Status", nil, intf_state_map[intf_state], { light = { class = intf_light_map[intf_state] } })
    if stats.link == "up" then
      html[#html + 1] = ui_helper.createLabel(T"Link Speed", format("%s Mbps",stats.speed))
      html[#html + 1] = ui_helper.createLabel(T"Mode", format("%s",stats.mode))
    end
    ngx.print(html, '\
</fieldset>\
<script type=\'text/javascript\'>\
function eth_ajax_modal()\
{\
  var url = \'/check.lp\';\
  var checktimer = ', TIMERJS or 5000, ';\
  $.getJSON(url,  {eth: "1",old_eth:"', stats.link, '"})\
   .done(function( data ) {\
      if (data.OLD_ETH != data.ETH){\
        tch.loadModal("/modals/broadband-modal.lp", "", function() {\
            $(".modal").modal();\
        });\
      } \
   })\
   .always(function() {\
          if (L2_check){clearTimeout(L2_check)};\
          L2_check = window.setTimeout(function () {eth_ajax_modal();}, checktimer);\
    });\
}\
eth_ajax_modal();\
</script>');