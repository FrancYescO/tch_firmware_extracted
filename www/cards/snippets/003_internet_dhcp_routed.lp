<%
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local format = string.format
local match = string.match

local interface_name = "wan"
local rpc_wan_path = format("rpc.network.interface.@%s.", interface_name)
local uci_wan_path = format("uci.network.interface.@%s.", interface_name)

local function getNetIntfPath(protocol)
	local uciPath = uci_wan_path..""
	local rpcPath = rpc_wan_path..""

	local content_wan = {
		wan_protype = uci_wan_path.."proto",
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
    elseif intf == "wan6" then
      cs.ip6addr = "rpc.network.interface.@wan6.ip6addr"
    elseif intf == interface_name then
      cs.ip6addr = rpc_wan_path.."ip6addr"
    end
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

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    switchName = "uci_wan_auto"
    modalPath = "/modals/internet-modal.lp"
end

%>

<%= ui_helper.createCardHeader(T"Internet Access", modalPath, nil, cs["uci_wan_auto"]) %>
<div class="content">
  <%= ui_helper.createSimpleLight(nil, dhcp_state_map[dhcp_state], { light = { class = dhcp_light_map[dhcp_state], id = "Internet_DHCP_LED" }, span = {id = "Internet_DHCP_Status"} }) %>
  <p class="subinfos">
     <%if dhcp_state == "connected" then
        if cs["ipaddr"] and cs["ipaddr"]:len() > 0 then
	  ngx.print(format(T'WAN IP is <strong id ="wan_ip">%s</strong>', cs["ipaddr"]))
	elseif cs["ip6addr"] and cs["ip6addr"]:len() > 0 then
	  ngx.print(format(T'WAN IP is <strong id ="wan_ip">%s</strong>', cs["ip6addr"]))
	end
      end%>
  </p>
</div>
