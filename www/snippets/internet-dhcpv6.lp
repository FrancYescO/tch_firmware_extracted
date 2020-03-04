--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local post_helper = require("web.post_helper")
local tonumber = tonumber

-- State data
local dhcp_state = "connecting"
local dhcp_state_map = {
    disabled = T"disabled",
    connected = T"connected",
    connecting = T"connecting",
}

local dhcp_light_map = {
  disabled = "off",
  connecting = "orange",
  connected = "green",
}

local ajax_attr = {
    span = {
      id = "ipaddr"
    }
}
local ajax_attr_light = {
    light = {
        class = ""
    },
    controls = {
        id = "wan_status",
    }
}

function get_dhcp_state(wan_auto, ipaddr)
    -- Figure out interface state
    if wan_auto ~= "0" then
        if ipaddr:len() > 0 then
            return "connected"
        else
            return "connecting"
        end
    else
        return "disabled"
    end
end

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean
-- Configurable data
local mapParams = {
    uci_wan_auto = "uci.network.interface.@wan6.auto",
}

local mapValid = {
    uci_wan_auto = vB,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- default value
if content["uci_wan_auto"] ~= "0" then
    content["uci_wan_auto"] = "1"
end

-- Non-configurable data
local cs = {
    ipaddr = "rpc.network.interface.@wan6.ip6addr",
    nexthop = "rpc.network.interface.@wan6.nexthop",
    dns = "rpc.network.interface.@wan6.dnsservers",
    rpc_ip6prefix = "rpc.network.interface.@wan6.ip6prefix",
    uci_delegate = "uci.network.interface.@wan6.delegate",
}

ajax_helper.handleAjaxQuery(cs, function(c)
    -- this will add the HTML for the light
    local ds = get_dhcp_state(content["uci_wan_auto"], c["ipaddr"])
    ajax_attr_light.light.class = dhcp_light_map[ds]
    c.wan_status = ui_helper.createSimpleLight(nil, dhcp_state_map[ds], ajax_attr_light)
end)
-- will stop in handleAjaxQuery if it is an actual AJAX query
content_helper.getExactContent(cs)

dhcp_state = get_dhcp_state(content["uci_wan_auto"], cs["ipaddr"])

  ngx.print('\
\
<fieldset>\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"DHCPv6 connection" ); ngx.print('</legend>\
\
');  
    local html = {}
    ajax_attr_light.light.class = dhcp_light_map[dhcp_state]
    html[#html + 1] = ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], ajax_attr_light)
    html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content["uci_wan_auto"])

    html[#html+1] = ui_helper.createLabel(T"IPv6 address", cs["ipaddr"], ajax_attr)
    ajax_attr.span.id = "nexthop"
    html[#html+1] = ui_helper.createLabel(T"Gateway", cs["nexthop"], ajax_attr)
    ajax_attr.span.id = "dns"
    html[#html+1] = ui_helper.createLabel(T"DNS servers", cs["dns"], ajax_attr)
    if cs["uci_delegate"] ~= "0" then
        ajax_attr.span.id = "rpc_ip6prefix"
        html[#html+1] = ui_helper.createLabel(T"IPv6 prefix delegation", cs["rpc_ip6prefix"], ajax_attr)
    end

    ngx.print(html)
  ngx.print('\
\
</fieldset>\
'); 