<%
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local format = string.format
local interface_name = "wan"
local rpc_wan_path = format("rpc.network.interface.@%s.", interface_name)
local uci_wan_path = format("uci.network.interface.@%s.", interface_name)

-- Non-configurable data
local cs = {
    uci_wan_auto = uci_wan_path.."auto",
    ipaddr = rpc_wan_path.."ipaddr",
}

content_helper.getExactContent(cs)

-- Figure out interface state
local static_state = "disabled"
local static_state_map = {
    disabled = T"Static disabled",
    connected = T"Static on",
}

local static_light_map = {
  disabled = "off",
  connected = "green",
}

if cs["uci_wan_auto"] ~= "0" and cs["ipaddr"]:len() > 0 then
    cs["uci_wan_auto"] = "1"
    static_state = "connected"
end

local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    modalPath = "/modals/internet-modal.lp"
end

%>

<%= ui_helper.createCardHeader(T"Internet Access", modalPath, nil, nil) %>
<div class="content">
  <%= ui_helper.createSimpleLight(nil, static_state_map[static_state], { light = { class = static_light_map[static_state] } }) %>
  <p class="subinfos">
     <% if static_state == "connected" then
            ngx.print(format(T'WAN IP is <strong>%s</strong>', cs["ipaddr"]))
        end
     %>
  </p>
</div>
