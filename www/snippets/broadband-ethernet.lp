<%
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format, untaint = string.format, string.untaint
local proxy = require("datamodel")
local interface_name = proxy.get("uci.env.custovar.wan_if")[1].value
local uci_wan_path = format("uci.network.interface.@%s.", interface_name)


local wan = {
    iface = uci_wan_path.."ifname",
}
content_helper.getExactContent(wan)

-- Here we just try to remove the potential vlan id from the interface name.
local iface = string.match(wan.iface, "([^%.]+)")
local stats

if iface then
    iface = iface:untaint()
    stats = {
        operstate = "sys.class.net.@" .. iface .. ".operstate",
        carrier = "sys.class.net.@" .. iface .. ".carrier",
        speed = "sys.class.net.@" .. iface .. ".speed",
    }
    content_helper.getExactContent(stats)
else
    stats = {
        operstate = "down",
        carrier = "0",
        speed = "0",
    }
end

-- Figure out interface state
local intf_state = "disabled"
local intf_state_map = {
    disabled = T"Ethernet disabled",
    connected = T"Ethernet connected",
    disconnected = T"Ethernet not connected",
}

local intf_light_map = {
  disabled = "off",
  disconnected = "red",
  connected = "green",
}

if stats.operstate == "up" then
    if stats.carrier ~= "0" then
        intf_state = "connected"
    else
        intf_state = "disconnected"
    end
else
    intf_state = "disabled"
end

%>

<fieldset>
  <legend><%= T"Physical link status" %></legend>

  <%
    local html = {}
    -- Label that shows Ethernet status
    html[#html + 1] = ui_helper.createLight(T"Status", nil, intf_state_map[intf_state], { light = { class = intf_light_map[intf_state] } })
    ngx.print(html)
  %>
</fieldset>
