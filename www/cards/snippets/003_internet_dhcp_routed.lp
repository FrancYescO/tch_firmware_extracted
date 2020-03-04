--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local format = string.format
local session = ngx.ctx.session
local interface_name = session:retrieve("network_interface_name") or ""

-- Non-configurable data
local cs = {
    uci_wan_auto = format("uci.network.interface.@%s.auto", interface_name),
    ipaddr = format("rpc.network.interface.@%s.ipaddr", interface_name)
}

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

  ngx.print('\
\
  ');  ngx.print( ui_helper.createSimpleLight(nil, dhcp_state_map[dhcp_state], { light = { class = dhcp_light_map[dhcp_state] } }) ); ngx.print('\
  <p class="subinfos">\
     ');  if dhcp_state == "connected" then
            ngx.print(format(T'WAN IP is <strong>%s</strong>', cs["ipaddr"]))
        end
       ngx.print('\
  </p>\
'); 