--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local format, upper = string.format, string.upper


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

-- Fetching all available wan interfaces
local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.",firewall_zone)
local all_intfs = {}
for _, v in ipairs(firewall_zone_path) do
    if v["wan"] == "1" and v["name"] ~= "mgmt" then
        all_intfs[v["name"]] = proxy.get("rpc.network.interface.@"..v["name"]..".ipaddr")
    end
end

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

  ngx.print('\
\
');  ngx.print( ui_helper.createCardHeader(T"Internet Access", modalPath, switchName, cs["uci_wan_auto"]) ); ngx.print('\
<div class="content card_bg" data-bg-text="&#xf0ec;">\
  ');  ngx.print( ui_helper.createSimpleLight(nil, dhcp_state_map[dhcp_state], { light = { class = dhcp_light_map[dhcp_state], id = "Internet_DHCP_LED" }, span = {id = "Internet_DHCP_Status"} }) ); ngx.print('\
  <p class="subinfos">\
     ');  for k,v in pairs(all_intfs) do
            if(v[1].value and v[1].value ~= "") then
                ngx.print(format(T'%s IP is <strong>%s</strong>', upper(k), v[1].value))  ngx.print('<br>');  
            end
        end
       ngx.print('\
  </p>\
</div>\
'); 