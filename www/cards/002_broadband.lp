--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local proxy = require ("datamodel")
local lp = require("web.lp")
local content_helper = require("web.content_helper")
local format, match = string.format, string.match
local wan = {
    iface = "uci.network.interface.@wan.ifname",
    port = "uci.network.interface.@wan.device",
    ppp = "rpc.network.interface.@wan.ppp.ll_intf",
    WS = "uci.wansensing.global.enable",
}
content_helper.getExactContent(wan)
wan.vlan = proxy.get("uci.network.device.@vlan_wan.ifname")
local stats
-- Here we just try to remove the potential vlan id from the interface name.
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
local cardpath = "snippets/002_broadband_xdsl.lp"
if  ifpath == "eth4" then 
   cardpath = "snippets/002_broadband_ethernet.lp"
end


ngx.print('\
<div class="span3">\
  <div class="smallcard">');
    lp.include(cardpath)
    -- have to bring it back to original value ... singleton
ngx.print('\
  </div>\
</div>');
if wan.WS ~= "0" then 
ngx.print('\
<script type=\'text/javascript\'>\
    //WAN Sensing Change detect\
    function WS_ajax()\
    {\
      var url = \'/check.lp\';\
      var checktimer = ', TIMERJS, ';\
      $.getJSON(url,  {WS: "1",old_L2:"', proxy.get("uci.wansensing.global.l2type")[1].value, '"})\
       .done(function( data ) {\
          if (data.OLD_L2 != data.L2){\
            window.setTimeout(function () {window.location.href = "/";}, 2000);\
          }\
       })\
       .always(function() {\
          clearTimeout(WS_check);\
          WS_check = window.setTimeout(function () { WS_ajax(); }, checktimer);\
       });\
    }\
    $(document).ready(function(){\
        WS_ajax();\
    });\
</script>');
end