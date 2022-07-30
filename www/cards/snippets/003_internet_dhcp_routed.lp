--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local format = string.format
local match = string.match
local session = ngx.ctx.session
local role = session:getrole()
local usersValue = session:getusername()
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "InternetCard", "card")
local readOnlyInternetCard = post_helper.getVariantValue(variantHelper, "readOnlyInternetCard")

local cs = {}
local IPv6State = "none"
local wanIntf = post_helper.getActiveInterface()
local wan6Intf = post_helper.getActiveInterface_v6()

local nwcommon = require("transformer.mapper.nwcommon")
local netMask = tonumber(proxy.get(format("rpc.network.interface.@%s.ipmask", wanIntf))[1].value)
local netMaskIp = netMask ~= "" and nwcommon.netmask2mask(netMask) or ""

local ipv6_light_map, ipv6_state_map = {}, {}

if post_helper.isFeatureEnabled("internetDhcpRouted", role) then
  local function getNetIntfPath(protocol)
          local uciPath = format("uci.network.interface.@%s.", wanIntf)
	  local rpcPath = format("rpc.network.interface.@%s.", wanIntf)

	  local content_wan = {
	          wan_protype = format("uci.network.interface.@%s.proto", wanIntf),
          }
	  content_helper.getExactContent(content_wan)
	  if content_wan.wan_protype ~= protocol then
	          uciPath = "uci.network.interface.@wan2."
	          rpcPath = "rpc.network.interface.@wan2."
	  end

	  return uciPath, rpcPath
  end

  local content_uci = {
    wan_ipv6 = format("uci.network.interface.@%s.ipv6", wanIntf)
  }

  for _,rpcPath in ipairs(proxy.getPN("rpc.network.interface.", true)) do
     local intf = match(rpcPath.path, "rpc%.network%.interface%.@([^%.]+)%.")
       if intf == "6rd" then
         content_uci.ip6addr = "rpc.network.interface.@6rd.ip6addr"
         content_uci.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
       elseif intf == wan6Intf then
         content_uci.ip6addr = format("rpc.network.interface.@%s.ip6addr" , wan6Intf)
         content_uci.ip6prefix = format("rpc.network.interface.@%s.ip6prefix", wan6Intf)
       end
  end

  content_helper.getExactContent(content_uci)

  local uci_dhcp_path, rpc_dhcp_path = getNetIntfPath("dhcp")

  -- Non-configurable data
  cs = {
      uci_wan_auto = uci_dhcp_path.."auto",
      ipaddr = rpc_dhcp_path.."ipaddr",
  }

  if content_uci.wan_ipv6 == "0" then
          IPv6State = "disabled"
  elseif content_uci.ip6prefix ~= "" then
          IPv6State = "prefix"
  elseif content_uci.ip6prefix == "" then
          IPv6State = "noprefix"
  end

  local untaint_mt = require("web.taint").untaint_mt
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

  for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
    local intf = match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
      if intf == "6rd" then
        cs.ip6addr = "rpc.network.interface.@6rd.ip6addr"
      elseif intf ==  wan6Intf then
        cs.ip6addr = "rpc.network.interface.@"..wan6Intf..".ip6addr"
      elseif intf == wanIntf then
        cs.ip6addr = "rpc.network.interface.@"..wanIntf..".ip6addr"
      end
  end
else
  local interface_name = session:retrieve("network_interface_name") or ""
  -- Non-configurable data
  cs = {
    uci_wan_auto = format("uci.network.interface.@%s.auto", interface_name),
    ipaddr = format("rpc.network.interface.@%s.ipaddr", interface_name)
  }
end

content_helper.getExactContent(cs)

-- Figure out interface state
local dhcp_state = "connecting"
local dhcp_state_map = {
    disabled = T"DHCP disabled",
    connected = T"DHCP on",
    connecting = T"DHCP connecting",
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

local switchName = nil
local modalPath = nil

if post_helper.isFeatureEnabled("internetDhcpRouted" , role) then
  if not readOnlyInternetCard or usersValue ~= 'assist' and readOnlyInternetCard then
    if session:hasAccess("/modals/internet-modal.lp") then
      modalPath = "/modals/internet-modal.lp"
      if post_helper.isFeatureEnabled("dhcpenable" , role) then
        switchName = "uci_wan_auto"
      end
    end
  end
end

  ngx.print('\
\
');  if post_helper.isFeatureEnabled("internetDhcpRouted" , role) then   ngx.print('\
  ');  ngx.print( ui_helper.createCardHeader(T"Internet Access", modalPath, switchName, cs["uci_wan_auto"]) ); ngx.print('\
  ');  if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
  <div class="content">\
  ');  else   ngx.print('\
  <div class="content card_bg" data-bg-text="&#xf0ec;">\
  ');  end   ngx.print('\
    ');  ngx.print( ui_helper.createSimpleLight(nil, dhcp_state_map[dhcp_state], { light = { class = dhcp_light_map[dhcp_state], id = "Internet_DHCP_LED" }, span = {id = "Internet_DHCP_Status"} }) ); ngx.print('\
    <p class="subinfos">\
       ');  if dhcp_state == "connected" then
          if cs["ipaddr"] and cs["ipaddr"]:len() > 0 then
            if post_helper.getVariantValue(variantHelper, "netMask") and netMaskIp ~= "" then
              ngx.print(format(T'WAN IP is <strong id ="wan_ip">%s</strong> and netmask is <strong id ="net_mask">%s</strong>', cs["ipaddr"], netMaskIp))
            else
              ngx.print(format(T'WAN IP is <strong id ="wan_ip">%s</strong>', cs["ipaddr"]))
            end
	  elseif cs["ip6addr"] and cs["ip6addr"]:len() > 0 then
	    ngx.print(format(T'WAN IP is <strong id ="wan_ip">%s</strong>', cs["ip6addr"]))
	  end
	if dhcp_state == "connected" and IPv6State ~= "none" then
          ngx.print(ui_helper.createSimpleLight(nil, ipv6_state_map[IPv6State] or T"Unknown", { light = { class = ipv6_light_map[IPv6State] or "red" } }))
          if post_helper.getVariantValue(variantHelper, "IPv6Address") and IPv6State == "prefix" and cs["ip6addr"]:len() > 0 then
            ngx.print(format(T'<p class="subinfos">IPv6 address is <strong>%s</strong></p>', cs["ip6addr"]))
          end
	end
      end  ngx.print('\
  </p>\
</div>\
');  else   ngx.print('\
  ');  ngx.print( ui_helper.createSimpleLight(nil, dhcp_state_map[dhcp_state], { light = { class = dhcp_light_map[dhcp_state] } }) ); ngx.print('\
  <p class="subinfos">\
     ');  if dhcp_state == "connected" then
          if post_helper.getVariantValue(variantHelper, "netMask") and netMaskIp ~= "" then
            ngx.print(format(T'WAN IP is <strong id ="wan_ip">%s</strong> and netmask is <strong id ="net_mask">%s</strong>', cs["ipaddr"], netMaskIp))
          else
            ngx.print(format(T'WAN IP is <strong>%s</strong>', cs["ipaddr"]))
          end
        end
       ngx.print('\
  </p>\
');  end   ngx.print('\
'); 