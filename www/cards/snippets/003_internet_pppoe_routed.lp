--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")

local table = table
local format = string.format
local session = ngx.ctx.session
local role = session:getrole()
local usersValue = session:getusername()
local variant_helper = require("variant_helper")
local cardHelper = post_helper.getVariant(variant_helper, "CardView", "card")
local cardViewGFR = post_helper.getVariantValue(cardHelper, "cardViewGFR")
local untaint_mt = require("web.taint").untaint_mt
local wanIntf = post_helper.getActiveInterface()
local wan6Intf = post_helper.getActiveInterface_v6()

local content_uci, content_rpc = {}, {}
if post_helper.isFeatureEnabled("internetPppoeRouted", role) then
  content_uci = {
    wan_proto = format("uci.network.interface.@%s.proto", wanIntf),
    wan_auto = format("uci.network.interface.@%s.auto", wanIntf),
    wan_ipv6 = format("uci.network.interface.@%s.ipv6", wanIntf),
  }
  content_rpc = {
    wan_ppp_state = format("rpc.network.interface.@%s.ppp.state", wanIntf),
    wan_ppp_error = format("rpc.network.interface.@%s.ppp.error", wanIntf),
    ipaddr = format("rpc.network.interface.@%s.ipaddr", wanIntf),
  }
  for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
    local intf = string.match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
    if intf then
      if intf == "6rd" then
        content_rpc.ip6addr = "rpc.network.interface.@6rd.ip6addr"
        content_rpc.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
      elseif intf == wan6Intf then
        content_rpc.ip6addr = "rpc.network.interface.@"..wan6Intf..".ip6addr"
        content_rpc.ip6prefix = "rpc.network.interface.@"..wan6Intf..".ip6prefix"
      end
    end
  end
else
  local interface_name = session:retrieve("network_interface_name") or wanIntf
  local basepath_uci = format("uci.network.interface.@%s.", interface_name)
  local basepath_rpc = format("rpc.network.interface.@%s.", interface_name)
  content_uci = {
    wan_proto = basepath_uci .. "proto",
    wan_auto = basepath_uci .. "auto",
  }
  content_rpc = {
    wan_ppp_state = basepath_rpc .. "ppp.state",
    wan_ppp_error = basepath_rpc .. "ppp.error",
    ipaddr = basepath_rpc .. "ipaddr",
  }
end
content_helper.getExactContent(content_uci)
content_helper.getExactContent(content_rpc)

local IPv6State = "none"
local ipv6_state_map, ipv6_light_map, ppp_state_map, ppp_light_map = {}, {}, {}, {}

if post_helper.isFeatureEnabled("internetPppoeRouted", role) then

  if content_uci.wan_ipv6 == "0" then
       IPv6State = "disabled"
  elseif content_rpc.ip6prefix ~= "" then
       IPv6State = "prefix"
  elseif content_rpc.ip6prefix == "" then
       IPv6State = "noprefix"
  end

  ipv6_state_map = {
      disabled = T"IPv6 Disabled",
      noprefix = T"IPv6 Connecting",
      prefix = T"IPv6 Connected",
  }

  setmetatable(ipv6_state_map, untaint_mt)

  ipv6_light_map = {
      disabled = "off",
      noprefix = "orange",
      prefix = "green",
  }
  setmetatable(ipv6_light_map, untaint_mt)
end

ppp_state_map = {
    disabled = T"PPP disabled",
    disconnecting = T"PPP disconnecting",
    connected = T"PPP connected",
    connecting = T"PPP connecting",
    disconnected = T"PPP disconnected",
    error = T"PPP error",
    AUTH_TOPEER_FAILED = T"PPP authentication failed",
    NEGOTIATION_FAILED = T"PPP negotiation failed",
}

setmetatable(ppp_state_map, untaint_mt)

ppp_light_map = {
    disabled = "off",
    disconnected = "red",
    disconnecting = "orange",
    connecting = "orange",
    connected = "green",
    error = "red",
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
  elseif post_helper.isFeatureEnabled("internetPppoeRouted", role) and not ppp_state_map[ppp_status] then
    ppp_status = "error"
  end

  if not (content_rpc.wan_ppp_error == "" or content_rpc.wan_ppp_error == "USER_REQUEST") then
    if ppp_state_map[content_rpc.wan_ppp_error] then
        ppp_status = content_rpc.wan_ppp_error
    else
        ppp_status = "error"
    end
  end
else
  -- WAN disabled
  ppp_status = "disabled"
end

local switchName = nil
local modalPath = nil
if post_helper.isFeatureEnabled("internetPppoeRouted" , role) then
  if not cardViewGFR or usersValue ~= 'assist' and cardViewGFR then
    if session:hasAccess("/modals/internet-modal.lp") then
      modalPath = "/modals/internet-modal.lp"
      if post_helper.isFeatureEnabled("dhcpenable" , role) then
        switchName = "uci_wan_auto"
      end
    end
  end
end
  ngx.print('\
');  if post_helper.isFeatureEnabled("internetPppoeRouted" , role) then  ngx.print('\
  ');  ngx.print( ui_helper.createCardHeader(T"Internet Access", modalPath, switchName, content_uci.wan_auto) ); ngx.print('\
  ');  if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
  <div class="content">\
  ');  else   ngx.print('\
  <div class="content card_bg" data-bg-text="&#xf0ec;">\
  ');  end   ngx.print('\
    ');  ngx.print( ui_helper.createSimpleLight(nil, ppp_state_map[ppp_status], { light = { class = ppp_light_map[ppp_status] } }) ); ngx.print('\
    <p class="subinfos">\
       ');  if ppp_status == "connected" then
         if content_rpc["ipaddr"] and content_rpc["ipaddr"]:len() > 0 then
           ngx.print(format(T'WAN IP is <strong>%s</strong>', content_rpc["ipaddr"]))
         elseif content_rpc["ip6addr"] and content_rpc["ip6addr"]:len() > 0 then
	   ngx.print(format(T'WAN IP is <strong>%s</strong>', content_rpc["ip6addr"]))
         end
	 if ppp_status == "connected" and IPv6State ~= "none" then
           ngx.print(ui_helper.createSimpleLight(nil, ipv6_state_map[IPv6State] or T"Unknown", { light = { class = ipv6_light_map[IPv6State] or "red" } }))
           if cardViewGFR and IPv6State == "prefix" and content_rpc["ip6addr"]:len() > 0 then
            ngx.print(format(T'<p class="subinfos">IPv6 address is <strong>%s</strong></p>', content_rpc["ip6addr"]))
          end
         end
       end  ngx.print('\
    </p>\
  </div>\
  <script>\
    var WANIP = "');  T'WAN IP is'  ngx.print('";\
  </script>\
<script src="/js/003_internet_pppoe_routed.js"></script>\
');  else  ngx.print('\
  ');  ngx.print( ui_helper.createSimpleLight(nil, ppp_state_map[ppp_status], { light = { class = ppp_light_map[ppp_status] } }) ); ngx.print('\
  <p class="subinfos">\
     ');  if ppp_status == "connected" then
            ngx.print(format(T'WAN IP is <strong>%s</strong>', content_rpc["ipaddr"]))
        end
       ngx.print('\
  </p>\
');  end  ngx.print('\
'); 