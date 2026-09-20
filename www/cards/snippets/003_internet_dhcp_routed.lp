<%
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local format = string.format


local session = ngx.ctx.session
local tech = false
if session:getrole() == "superuser" or session:getrole() == "telia" then
   tech = true
end

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
content_helper.getExactContent(cs)

local cs_voip = { ipaddr = "rpc.network.interface.@voip.ipaddr" }
content_helper.getExactContent(cs_voip)

local cs_iptv = { ipaddr = "rpc.network.interface.@iptv.ipaddr" }
content_helper.getExactContent(cs_iptv)

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
	if tech then
		switchName = "uci_wan_auto"
	end
    modalPath = "/modals/internet-modal.lp"
end

%>

<%= ui_helper.createCardHeader(T"Internet Access", modalPath, switchName, cs["uci_wan_auto"]) %>
<div class="content">
  <%= ui_helper.createSimpleLight(nil, dhcp_state_map[dhcp_state], { light = { class = dhcp_light_map[dhcp_state] } }) %>
  <p class="subinfos">
     <% if dhcp_state == "connected" then
            ngx.print(format(T'WAN IP is <strong>%s</strong>', cs["ipaddr"]))
        end
        if cs_voip["ipaddr"] ~= "" then %><br><%
            ngx.print(format(T'VoIP IP is <strong>%s</strong>', cs_voip["ipaddr"]))
        end
        if cs_iptv["ipaddr"] ~= "" then %><br><%
            ngx.print(format(T'IPTV IP is <strong>%s</strong>', cs_iptv["ipaddr"]))
        end
     %>
  </p>
</div>
