--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local session = ngx.ctx.session
local modalPath = "/modals/relay-modal.lp"
if session:hasAccess(modalPath) then

-- TODO: Hardcoded to "1" since there’s no option to enable/disable dhcp relay
local uci_relay_status = "1"
local dhcprelay_state = "connected"

local relay_Params = {
	uci_username = "uci.network.interface.@wan.username",	
	uci_relay_server_ip = "uci.dhcp.relay.@relay.server_addr",
	uci_relay_local_ip = "uci.dhcp.relay.@relay.local_addr",
}
content_helper.getExactContent(relay_Params)

local PPP_status = T"Not Configured"


if relay_Params["uci_username"] ~= "" then
   PPP_status = T"Configured"
end

if relay_Params["uci_relay_server_ip"] == "" and relay_Params["uci_relay_local_ip"] == "" then
  uci_relay_status = "0"
  dhcprelay_state = "disabled"
end


local dhcp_light_map = {
  disabled = "off",
  connected = "green",
}
local dhcp_state_map = {
    disabled = T"DHCP Relay Disabled",
    connected = T"DHCP Relay Enabled",
}

ngx.print('\
<div class="span3">\
    <div class="smallcard">',
    ui_helper.createCardHeader(T"Relay Setup", "modals/relay-modal.lp"), '\
          <div class="content card_bg" data-bg-text="&#xf0ad;">\
      	  <div class="divtable">',
          format("<div class=\"subinfos\"><span>%s: </span><span><b>%s</b></span></div>",T"PPP Status", PPP_status),
          ui_helper.createSimpleLight(nil, dhcp_state_map[dhcprelay_state] , { light = { class = dhcp_light_map[dhcprelay_state], id = "relaysetupcard_dhcprelaystatusled" },  span = { id = "relaysetupcard_dhcprelaystatus" }}));
          if uci_relay_status ~=  "0" then
            ngx.print(format('<p class = "subinfos" > Server IP : <strong id="relaysetupcard_relayip">%s</strong></p>',relay_Params["uci_relay_server_ip"] ),
            format('<p class = "subinfos" > Local IP : <strong id="relaysetupcard_relayip">%s</strong></p>',relay_Params["uci_relay_local_ip"] ));
          end
	     ngx.print('</div>\
     </div>\
    </div>\
</div>');
end 