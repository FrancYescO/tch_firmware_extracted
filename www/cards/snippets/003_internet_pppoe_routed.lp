--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")

local table = table
local format = string.format
local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_auto = "uci.network.interface.@wan.auto",
  wan_ipv6 = "uci.network.interface.@wan.ipv6",
}
content_helper.getExactContent(content_uci)

local content_rpc = {
  wan_ppp_state = "rpc.network.interface.@wan.ppp.state",
  wan_ppp_error = "rpc.network.interface.@wan.ppp.error",
  ipaddr = "rpc.network.interface.@wan.ipaddr",
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = string.match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
  if intf then
    if intf == "6rd" then
      content_rpc.ip6addr = "rpc.network.interface.@6rd.ip6addr"
      content_rpc.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
    elseif intf == "wan6" then
     content_rpc.ip6addr = "rpc.network.interface.@wan6.ip6addr"
     content_rpc.ip6prefix = "rpc.network.interface.@wan6.ip6prefix"
    end
  end
end

content_helper.getExactContent(content_rpc)

local IPv6State = "none"

if content_uci.wan_ipv6 ~= "1" then
     IPv6State = "disabled"
elseif content_rpc.ip6prefix ~= "" then
     IPv6State = "prefix"
elseif content_rpc.ip6prefix == "" then
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

local ppp_state_map = {
    disabled = T"PPP Disabled",
    disconnecting = T"PPP Disconnecting",
    connected = T"PPP Connected",
    connecting = T"PPP Connecting",
    disconnected = T"PPP Disconnected",
    error = T"PPP error",
    networking = T"Network Error",
    noconf = T"PPP Not Configured",
    AUTH_TOPEER_FAILED = T"PPP Authentication Failed",
    NEGOTIATION_FAILED = T"PPP Negotiation Failed",
}

local untaint_mt = require("web.taint").untaint_mt
setmetatable(ppp_state_map, untaint_mt)


local ppp_light_map = {
    disabled = "off",
    noconf = "off",
    disconnected = "red",
    disconnecting = "orange",
    connecting = "orange",
    connected = "green",
    error = "red",
    networking = "red",
    AUTH_TOPEER_FAILED = "red",
    NEGOTIATION_FAILED = "red",
}

setmetatable(ppp_light_map, untaint_mt)

local ppp_status
if content_uci.wan_auto ~= "0" then
  -- WAN enabled
  content_uci.wan_auto = "1"
  ppp_status = format("%s", content_rpc.wan_ppp_state) -- untaint
  if ppp_status == "" or ppp_status == "authenticating" then
    ppp_status = "connecting"
  elseif not ppp_state_map[ppp_status] then
    ppp_status = "error"
  end

  if not (content_rpc.wan_ppp_error == "" or content_rpc.wan_ppp_error == "USER_REQUEST") then
    if ppp_state_map[content_rpc.wan_ppp_error] then
        ppp_status = content_rpc.wan_ppp_error
    else
         if content_uci.wan_username ~= "" then
            ppp_status = "error"
         else
            ppp_status = "noconf"
         end
    end
  end
else
  -- WAN disabled
  ppp_status = "disabled"
end

local modalPath = "/modals/internet-modal.lp"

local session = ngx.ctx.session

ngx.print(ui_helper.createCardHeader(T"Internet Access", modalPath, nil, content_uci.wan_auto), '\
<div class="content card_bg" data-bg-text="&#xf0ac;">\
   <div class="divtable">\
        <div id="L3light">', ui_helper.createSimpleLight(nil, ppp_state_map[ppp_status] or T"Unknown", { light = { class = ppp_light_map[ppp_status] or "red" } }), '</div>');
        local html = {}
        html[#html+1] = "<p class=\"subinfos\" id=\"WANIP\">"
        if ppp_status == "connected" then
         html[#html+1] = format(T'WAN IP : <strong>%s</strong>', content_rpc["ipaddr"])
        end
        html[#html+1] = "</p>"
	html[#html+1] = "<div id=\"WANIPv6\">"
        if ppp_status == "connected" and IPv6State ~= "disabled" then

            html[#html+1] = ui_helper.createSimpleLight(nil, ipv6_state_map[IPv6State] or T"Unknown", { light = { class = ipv6_light_map[IPv6State] or "red" } })

        end
	html[#html+1] = "</div>"
        ngx.print(html,'\
  </div>\
</div>\
<script type=\'text/javascript\'>\
var ppp_state_map = {');
for k,v in pairs(ppp_state_map) do
     ngx.print(k, ' : "', v, '",');
end
ngx.print('};\
\
var ppp_light_map = {');
for k,v in pairs(ppp_light_map) do
     ngx.print(k, ' : "', v, '",');
end
ngx.print('};\
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
ngx.print('};\
\
function ppp_ajax(x)\
{\
  var url = \'/check.lp\';\
  var checktimer = ', TIMERJS or 5000, ';\
  $.getJSON(url,  {ppp: "1",old_ppp:x})\
   .done(function( data ) {\
      var ppp_status = data.PPP;\
      x = ppp_status;\
      //if (data.OLD_PPP != ppp_status){\
\
        var ppp_error = data.PPP_ERROR;\
        var ppp_auto = data.PPP_AUTO;\
        var ppp_ip = data.PPP_IP;\
        var ppp_username = data.PPP_UN;\
        var ppp_IPv6 = data.PPP_IPv6;\
        var PPP_IPv6PREFIX = data.PPP_IPv6PREFIX;\
        var ipv6_status = "none"\
\
        if (ppp_IPv6 == "0") {\
            ipv6_status = "disabled"\
        }else if (PPP_IPv6PREFIX.length > 0) {\
             ipv6_status = "prefix"\
        }else if (PPP_IPv6PREFIX.length == 0) {\
             ipv6_status = "noprefix"\
        }\
\
\
        if (ppp_status == "" || ppp_status == "authenticating") {\
          ppp_status = "connecting";\
        }\
        if (ppp_auto == "1"){\
          if (!(ppp_error == "" || ppp_error == "USER_REQUEST")){\
             if (ppp_state_map[ppp_error]) {\
                ppp_status = ppp_error;\
             }else{\
                if (ppp_username == ""){\
                  ppp_status = "noconf"\
                }else{\
                  ppp_status = "error";\
                }\
             }\
          }\
        }else{\
          ppp_status = "disabled";\
        }\
        if (ppp_username == ""){\
                  ppp_status = "noconf"\
        }\
          $("#L3light").html("<span class=\'simple-desc\'><div class=\'light "+ppp_light_map[ppp_status]+"\'></div>"+ppp_state_map[ppp_status]+"</span>");\
          var IPHTML = ""\
          if (ppp_status == "connected"){\
                IPHTML = "', T"WAN IP", ' : <strong>"+ppp_ip+"</strong>";\
          }\
          $("#WANIP").html(IPHTML);\
          if (ppp_IPv6 == "1"){\
              $("#WANIPv6").html("<span class=\'simple-desc\'><div class=\'light "+ipv6_light_map[ipv6_status]+"\'></div>"+ipv6_state_map[ipv6_status]+"</span>");\
          }else{$("#WANIPv6").html("");}\
      //} \
   }).always(function() {\
          if (L3_check){clearTimeout(L3_check)};\
          L3_check = window.setTimeout(function () {ppp_ajax(x);}, checktimer);\
    });\
}\
ppp_ajax("', content_rpc.wan_ppp_state, '");\
</script>');