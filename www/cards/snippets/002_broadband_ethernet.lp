--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format, match = string.format, string.match
local floor = math.floor
local tonumber = tonumber

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")


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

local session = ngx.ctx.session
local modalPath
modalPath = "modals/broadband-modal.lp"
ngx.print(ui_helper.createCardHeader(T"Broadband", modalPath), '\
<div class="content card_bg" data-bg-text="&#xf0b2;">\
      <div class="divtable">\
      <div id="L2light">', ui_helper.createSimpleLight(nil, intf_state_map[intf_state], { light = { class = intf_light_map[intf_state] } }), '</div>\
      <p class="subinfos" id="eth_speed">');
      if stats.link == "1" then
                  ngx.print(format("%s: %s Mbs",T"Link Speed",stats.speed))
      end
ngx.print('\
      </p>\
      </div>\
</div>\
<script type=\'text/javascript\'>\
var eth_state_map = {');
for k,v in pairs(intf_state_map) do
     ngx.print(k, ' : "', v, '",')
end
ngx.print('\};\
var eth_light_map = {');
for k,v in pairs(intf_light_map) do
     ngx.print(k, ' : "', v,'",');
end
ngx.print('\};\
function eth_ajax(x)\
{\
  var url = \'/check.lp\';\
  var checktimer = ', TIMERJS, ';\
  $.getJSON(url,  {eth: "1",old_eth:"', stats.link, '"})\
   .done(function( data ) {\
      var eth_link = data.ETH;\
      x = eth_link;\
      var eth_rate = data.ETH_SPEED\
      var eth_status = "Disconnected"\
      if (eth_link == "up"){eth_status = "Connected"}\
      $("#L2light").html("<span class=\\"simple-desc\\"><div class=\\"light "+eth_light_map[eth_status]+"\\"></div>"+eth_state_map[eth_status]+"</span>");\
        var ETHHTML = ""\
        if (eth_link == "up"){\
            ETHHTML = \'', T"Link Speed", ' :\'+eth_rate+\' Mbps\';\
        }\
        $("#eth_speed").html(ETHHTML);\
   })\
   .always(function() {\
          clearTimeout(L2_check);\
          L2_check = window.setTimeout(function () {eth_ajax(x);}, checktimer);\
    });\
}\
$(document).ready(function(){\
        eth_ajax("', stats.link, '");\
});\
</script>');
