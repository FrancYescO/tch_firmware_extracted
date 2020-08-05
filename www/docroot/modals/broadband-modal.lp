--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local proxy = require ("datamodel")
local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local format, match = string.format, string.match
local stats

local wan = {
    iface = "uci.network.interface.@wan.ifname",
    port = "uci.network.interface.@wan.device",
    ppp = "rpc.network.interface.@wan.ppp.ll_intf",
    WS = "uci.env.custovar.WS",
}
content_helper.getExactContent(wan)
wan.vlan = proxy.get("uci.network.device.@vlan_wan.ifname")

-- Here we just try to remove the potential vlan id from the interface name.
local iface = wan.iface
local iface = wan.iface
if match(iface,"eth4") then
  iface = "eth4"
elseif match(iface,"ptm0") then
  iface = "ptm0"
elseif match(iface,"atm0") then
  iface = "atm0"
elseif match(iface,"vlan_wan") then
  iface = "vlan_wan"
end 

local port = wan.port
local ppp = wan.ppp
local vlan_ifname = ""
if wan.vlan then 
   vlan_ifname = wan.vlan[1].value
end

if match(iface, "vlan_wan") then
   iface = vlan_ifname
end
local ifpath = iface
if iface == "pppoe-wan" or iface == "pppoa-wan" then
   ifpath = ppp
end
local adv = true
local modalpath = "broadband-xdsl.lp"
if  ifpath == "eth4" then 
   modalpath = "broadband-ethernet.lp"
   adv = false
end

ngx.print(ui_helper.createHeader(T"Broadband", adv, true), '\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/broadband-modal.lp">');
lp.setpath("/www/snippets/")
lp.include(modalpath)
ngx.print('\
</form>\
</div>',
ui_helper.createFooter());
if wan.WS ~= "2" then
ngx.print('\
<script type=\'text/javascript\'>\
    //WAN Sensing Change detect\
    function WS_ajax_modal()\
    {\
      var url = \'/check.lp\';\
      var checktimer = ', TIMERJS or 5000, ';\
      $.getJSON(url,  {WS: "1",old_L2:"', format("%s",proxy.get("uci.wansensing.global.l2type")[1].value), '"})\
       .done(function( data ) {\
          if (data.OLD_L2 != data.L2){\
            tch.loadModal("/modals/broadband-modal.lp", "", function() {\
                $(".modal").modal();\
            });\
          }\
       })\
       .always(function() {\
          if (WS_check){clearTimeout(WS_check)};\
          WS_check = window.setTimeout(function () {WS_ajax_modal();}, checktimer);\
       });\
    }\
    WS_ajax_modal();\
</script>');
end

