<%
-- Enable localization
gettext.textdomain('webui-core')

ngx.ctx.session:store("network_interface_name", "wan")

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local post_helper = require("web.post_helper")
local tonumber = tonumber
local untaint = string.untaint

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

local cvtBoolean = {
    ["0"] = "1",
    ["1"] = "0",
}

local ajax_attr = {
    span = {
      ["data-ajaxrefresh"] = "5",
    }
}
local ajax_attr_light = {
    light = {
        class = ""
    },
    controls = {
        id = "wan_status",
        ["data-ajaxrefresh"] = "5",
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

local wans_stat = {
    uci_wansensing_enable = "uci.wansensing.global.enable",
}
content_helper.getExactContent(wans_stat)

-- Non-configurable data
local cs = {
    ipaddr = "rpc.network.interface.@ipoe.ipaddr",
    nexthop = "rpc.network.interface.@ipoe.nexthop",
    dns = "rpc.network.interface.@ipoe.dnsservers",
    uci_wan_auto = "uci.network.interface.@ipoe.auto",
}

ajax_helper.handleAjaxQuery(cs, function(c)
    -- this will add the HTML for the light
    local ds = get_dhcp_state(cs["uci_wan_auto"], c["ipaddr"])
    ajax_attr_light.light.class = dhcp_light_map[ds]
    c.wan_status = ui_helper.createSimpleLight(nil, dhcp_state_map[ds], ajax_attr_light)
end)
-- will stop in handleAjaxQuery if it is an actual AJAX query
content_helper.getExactContent(cs)

dhcp_state = get_dhcp_state(cs["uci_wan_auto"], cs["ipaddr"])

-- dhcp lease data
cs["leaseobtained"] = ""
cs["leaseexpires"] = ""
if dhcp_state == "connected" then
    local dhcp_lease = {
        uptime = "rpc.system.uptime",
        connect_time = "uci.network.interface.@ipoe.connect_time",
        lease = "uci.network.interface.@ipoe.lease",
        lease_expires = "uci.network.interface.@ipoe.lease_expires",
    }

    content_helper.getExactContent(dhcp_lease)

    cs["leaseobtained"] = os.date("%F %T", os.time() - (tonumber(dhcp_lease["uptime"]) - (tonumber(dhcp_lease["lease_expires"]) - tonumber(dhcp_lease["lease"]))))
    cs["leaseexpires"] = os.date("%F %T", os.time() + (tonumber(dhcp_lease["lease_expires"]) - tonumber(dhcp_lease["uptime"])))
end

%>

<% ngx.print(ui_helper.createHeader(T"VoIP Access", false, true)) %>

<div class="modal-body update">
<form class="form-horizontal" method="post" action="modals/ipoe-modal.lp">

<fieldset>
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<legend><%= T"DHCP connection" %></legend>

<%
    local html = {}
    ajax_attr_light.light.class = dhcp_light_map[dhcp_state]
    html[#html + 1] = ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], ajax_attr_light)

    ajax_attr.span.id = "ipaddr"
    html[#html+1] = ui_helper.createLabel(T"IP address", cs["ipaddr"], ajax_attr)
if cs["ip6addr"] and cs["ip6addr"]:len() > 0 then
    ajax_attr.span.id = "ip6addr"
    html[#html+1] = ui_helper.createLabel(T"IPv6 address", cs["ip6addr"], ajax_attr)
end
    ajax_attr.span.id = "nexthop"
    html[#html+1] = ui_helper.createLabel(T"Gateway", cs["nexthop"], ajax_attr)
    ajax_attr.span.id = "dns"
    html[#html+1] = ui_helper.createLabel(T"DNS servers", cs["dns"], ajax_attr)
    html[#html+1] = ui_helper.createLabel(T"Lease obtained", cs["leaseobtained"])
    html[#html+1] = ui_helper.createLabel(T"Lease expires", cs["leaseexpires"])

    ngx.print(html)
%>

</fieldset>
<fieldset>
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>

</fieldset>
</form>
</div>

<% ngx.print(ui_helper.createFooter()) %>

