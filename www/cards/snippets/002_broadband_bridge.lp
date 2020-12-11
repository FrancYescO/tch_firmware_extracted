<%
-- Enable localization
gettext.textdomain('webui-core')

local format, match = string.format, string.match
local tonumber = tonumber

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local bridged = require("bridgedmode_helper")

local wan = {
    iface = "uci.network.interface.@wan.ifname",
}
content_helper.getExactContent(wan)

-- Figure out interface state
local intf_state_map = {
    disabled = T"Bridge disabled",
    connected = T"Bridge connected",
    disconnected = T"Bridge not connected",
}

local intf_light_map = {
  disabled = "off",
  disconnected = "red",
  connected = "green",
}
local intf_state = "disabled"

for v in string.gmatch(wan.iface, "[^%s]+") do
    -- Here we just try to remove the potential vlan id from the interface name.
    local iface = match(v, "([^%.]+)")
    iface = iface:untaint()
    local stats = {
        operstate = "sys.class.net.@" .. iface .. ".operstate",
        carrier = "sys.class.net.@" .. iface .. ".carrier",
    }
    content_helper.getExactContent(stats)

    if stats.operstate == "up" then
        if stats.carrier ~= "0" then
            intf_state = "connected"
        else
            intf_state = intf_state ~= "connected" and "disconnected"
        end
    end
end

local session = ngx.ctx.session
local modalPath

if not bridged.isBridgedMode() then
   if session:hasAccess("/modals/broadband-modal.lp") then
     modalPath = "modals/broadband-modal.lp"
   end
else
   if session:hasAccess("/modals/broadband-bridge-modal.lp") then
     modalPath = "modals/broadband-bridge-modal.lp"
   end
end

%>

<%= ui_helper.createCardHeader(T"Broadband", modalPath) %>
<div class="content">
  <%
    local html = {
      ui_helper.createSimpleLight(nil, intf_state_map[intf_state], {light = {class = intf_light_map[intf_state]}}),
      '<p class="subinfos">',
      format(T'Interfaces:<strong>%s</strong>', wan.iface),
      '</p>',
    }
    ngx.print(html)
  %>
</div>
