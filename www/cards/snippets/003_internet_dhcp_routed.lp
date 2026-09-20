--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local format = string.format
local match = string.match

local function getNetIntfPath(protocol)
	local uciPath = "uci.network.interface.@wan."
	local rpcPath = "rpc.network.interface.@wan."

	local content_wan = {
		wan_protype = "uci.network.interface.@wan.proto",
	}
	content_helper.getExactContent(content_wan)
	if content_wan.wan_protype ~= protocol then
		uciPath = "uci.network.interface.@wan2."
		rpcPath = "rpc.network.interface.@wan2."
	end

	return uciPath, rpcPath
end

local uci_dhcp_path, rpc_dhcp_path = getNetIntfPath("dhcp")

-- Non-configurable data
local cs = {
    uci_wan_auto = uci_dhcp_path.."auto",
    ipaddr = rpc_dhcp_path.."ipaddr",
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
    if intf == "6rd" then
      cs.ip6addr = "rpc.network.interface.@6rd.ip6addr"
      cs.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
    elseif intf == "wan6" then
      cs.ip6addr = "rpc.network.interface.@wan6.ip6addr"
      cs.ip6prefix = "rpc.network.interface.@wan6.ip6prefix"
    elseif intf == "wan" then
      cs.ip6addr = "rpc.network.interface.@wan.ip6addr"
      cs.ip6prefix = "rpc.network.interface.@wan.ip6prefix"
    end
end

content_helper.getExactContent(cs)


local IPv6State = "none"

if cs.wan_ipv6 ~= "1" then
	IPv6State = "disabled"
elseif cs.ip6prefix ~= "" then
	IPv6State = "prefix"
elseif cs.ip6prefix == "" then
	IPv6State = "noprefix"
end

local untaint_mt = require("web.taint").untaint_mt
local ipv6_state_map = {
     none = T"IPv6 Disabled",
     noprefix = T"IPv6 Connecting",
     prefix = T"IPv6 Connected",
}
setmetatable(ipv6_state_map, untaint_mt)

local ipv6_light_map = {
     none = "off",
     noprefix = "orange",
     prefix = "green",
}
setmetatable(ipv6_light_map, untaint_mt)


-- Figure out interface state
local dhcp_state = "connecting"
local dhcp_state_map = {
    disabled = T"DHCP Disabled",
    connected = T"DHCP Connected",
    connecting = T"DHCP Connecting",
}

local dhcp_light_map = {
  disabled = "off",
  connecting = "orange",
  connected = "green",
}

if cs["uci_wan_auto"] ~= "0" then
    cs["uci_wan_auto"] = "1"
    if cs["ipaddr"]:len() > 0 then
        dhcp_state = "connected"
    else
        dhcp_state = "connecting"
    end
else
    dhcp_state = "disabled"
end


local modalPath = "/modals/internet-modal.lp"



ngx.print(ui_helper.createCardHeader(T"Internet Access", modalPath, nil, cs["uci_wan_auto"]), '\
<div class="content card_bg" data-bg-text="&#xf0ac;">\
   <div class="divtable">\
  <div id="L3light">', ui_helper.createSimpleLight(nil, dhcp_state_map[dhcp_state], { light = { class = dhcp_light_map[dhcp_state], id = "Internet_DHCP_LED" }, span = {id = "Internet_DHCP_Status"} }), '</div>');
  local html = {}
  html[#html+1] = [[<p class="subinfos" id="WANIP">]]
  if dhcp_state == "connected" then
	if cs["ipaddr"] and cs["ipaddr"]:len() > 0 then
	  html[#html+1] = format(T'WAN IP : <strong>%s</strong>', cs["ipaddr"])	
	end
  end
  html[#html+1] = [[</p>]]
  html[#html+1] = [[<div id="WANIPv6">]]
  if dhcp_state == "connected" and IPv6State ~= "disabled" then
            html[#html+1] = ui_helper.createSimpleLight(nil, ipv6_state_map[IPv6State] or T"Unknown", { light = { class = ipv6_light_map[IPv6State] or "red" } })      
  end
  html[#html+1] = [[</div>]]
  ngx.print(html,'\
</div>\
</div>\
\
<script type=\'text/javascript\'>\
var dhcp_state_map = {');
for k,v in pairs(dhcp_state_map) do
     ngx.print(k, ' : "', v, '",');
end
ngx.print('};\
\
var dhcp_light_map = {');
for k,v in pairs(dhcp_light_map) do
     ngx.print(k, ' : "', v, '",');
end
ngx.print('}\
\
var ipv6_state_map = {');
for k,v in pairs(ipv6_state_map) do
     ngx.print(k, ' : "', v, '",');
end
ngx.print('};\
\
var ipv6_light_map = {');
for k,v in pairs(ipv6_light_map) do
     ngx.print(k, ' : "', v, '",');
end
ngx.print('}\
\
function dhcp_ajax(x)\
{\
  var url = \'/check.lp\';\
  var checktimer = ', TIMERJS or 5000,';\
  $.getJSON(url,  {dhcp: "1",old_dhcp:x})\
   .done(function( data ) {\
      var dhcp_ip = data.DHCP;\
      x =  dhcp_ip;\
      //if (data.OLD_DHCP != dhcp_ip){\
        var dhcp_auto = data.DHCP_AUTO;\
        var dhcp_status = "connecting";\
        if (dhcp_auto != "1"){\
            dhcp_status = "disabled";\
        }else{\
            if (dhcp_ip.length > 0) {\
                dhcp_status = "connected";\
            }else{\
                dhcp_status = "connecting";\
            }\
        }\
\
	var dhcp_IPv6 = data.DHCP_IPv6;\
        var dhcp_IPv6PREFIX = data.DHCP_IPv6PREFIX;\
        var ipv6_status = "none"\
        \
        if (dhcp_IPv6 == "0") {\
            ipv6_status = "disabled"\
        }else if (dhcp_IPv6PREFIX.length > 0) {\
             ipv6_status = "prefix"\
        }else if (dhcp_IPv6PREFIX.length == 0) {\
             ipv6_status = "noprefix"\
        }\
\
        $("#L3light").html("<span class=\'simple-desc\'><div class=\'light "+dhcp_light_map[dhcp_status]+"\'></div>"+dhcp_state_map[dhcp_status]+"</span>");\
        var IPHTML = ""\
        if (dhcp_status == "connected"){\
              IPHTML = "', T"WAN IP", ' : <strong>"+dhcp_ip+"</strong>";\
        if (dhcp_IPv6 == "1"){\
        $("#WANIPv6").html("<span class=\'simple-desc\'><div class=\'light "+ipv6_light_map[ipv6_status]+"\'></div>"+ipv6_state_map[ipv6_status]+"</span>");\
              }\
        }\
        $("#WANIP").html(IPHTML);\
      //}\
   }).always(function() {\
          if (L3_check){clearTimeout(L3_check)};\
          L3_check = window.setTimeout(function () {dhcp_ajax(x);}, checktimer);\
    });\
}\
dhcp_ajax();\
</script>');