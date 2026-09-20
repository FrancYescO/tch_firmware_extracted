<%
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

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean
local gVIES = post_helper.getValidateInEnumSelect

-- Non-configurable data
local cs = {
    ipaddr = "rpc.network.interface.@wan6.ip6addr",
    nexthop = "rpc.network.interface.@wan6.nexthop",
    dns = "rpc.network.interface.@wan6.dnsservers",
    rpc_ip6prefix = "rpc.network.interface.@wan6.ip6prefix",
    isp = "uci.mmpbxrvsipnet.network.@sip_net.isp",
    pppUsername = "uci.network.interface.@wan.username",
}

content_helper.getExactContent(cs)

local restrictions
if cs["isp"] == "Internode" then
    restrictions = {
        {"Off", T"<strong>Off</strong>"},
        {"Dynamic", T"<strong>@dynamic</strong>"},
        {"On", T"<strong>/64 prefix delegation restricted to lan</strong>"}
    }
else
    restrictions = {
        {"Off", T"<strong>Off</strong>"},
        {"On", T"<strong>/64 prefix delegation restricted to lan</strong>"}
    }
end

local function validateRestrictions(value, object, key)
    local success = gVIES(restrictions)
	if success then
        if object[key] == "On" or (object[key] == "Dynamic" and string.find(cs["pppUsername"],"@dynamic")) then
            object["lan_ip6assign"] = "64"
            object["guest1_ip6assign"] = ""
            object["Guest1_5GHz_ip6assign"] = ""
            object["VLAN1_ip6assign"] = ""
            object["VLAN2_ip6assign"] = ""
            object["VLAN3_ip6assign"] = ""
        else
            object["lan_ip6assign"] = "64"
            object["guest1_ip6assign"] = "64"
            object["Guest1_5GHz_ip6assign"] = "64"
            object["VLAN1_ip6assign"] = "64"
            object["VLAN2_ip6assign"] = "64"
            object["VLAN3_ip6assign"] = "64"
        end
        success = success and proxy.apply()
	end
    return success
end

-- Configurable data
local mapParams = {
    uci_wan_auto = "uci.network.interface.@wan6.auto",
    uci_delegate = "uci.network.interface.@wan6.delegate",
    delegateRestriction = "uci.network.interface.@wan6.delegateRestriction",
    lan_ip6assign = "uci.network.interface.@lan.ip6assign",
    guest1_ip6assign = "uci.network.interface.@Guest1.ip6assign",
    Guest1_5GHz_ip6assign = "uci.network.interface.@Guest1_5GHz.ip6assign",
    VLAN1_ip6assign = "uci.network.interface.@VLAN1.ip6assign",
    VLAN2_ip6assign = "uci.network.interface.@VLAN2.ip6assign",
    VLAN3_ip6assign = "uci.network.interface.@VLAN3.ip6assign",
}

local mapValid = {
    uci_wan_auto = vB,
    delegateRestriction = validateRestrictions,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- default value
if content["uci_wan_auto"] ~= "0" then
    content["uci_wan_auto"] = "1"
end
if content["uci_delegate"] ~= "0" then
    content["uci_delegate"] = "1"
end

ajax_helper.handleAjaxQuery(cs, function(c)
    -- this will add the HTML for the light
    local ds = get_dhcp_state(content["uci_wan_auto"], c["ipaddr"])
    ajax_attr_light.light.class = dhcp_light_map[ds]
    c.wan_status = ui_helper.createSimpleLight(nil, dhcp_state_map[ds], ajax_attr_light)
end)
-- will stop in handleAjaxQuery if it is an actual AJAX query

dhcp_state = get_dhcp_state(content["uci_wan_auto"], cs["ipaddr"])

%>

<fieldset>
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<legend><%= T"DHCPv6 connection" %></legend>

<%
    local html = {}
    ajax_attr_light.light.class = dhcp_light_map[dhcp_state]
    html[#html + 1] = ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], ajax_attr_light)
    html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content["uci_wan_auto"])

    ajax_attr.span.id = "ipaddr"
    html[#html+1] = ui_helper.createLabel(T"IPv6 address", cs["ipaddr"], ajax_attr)
    ajax_attr.span.id = "nexthop"
    html[#html+1] = ui_helper.createLabel(T"Gateway", cs["nexthop"], ajax_attr)
    ajax_attr.span.id = "dns"
    html[#html+1] = ui_helper.createLabel(T"DNS servers", cs["dns"], ajax_attr)
    if content["uci_delegate"] == "1" then
        html[#html+1] = ui_helper.createLabel(T"IPv6 prefix delegation", cs["rpc_ip6prefix"])
		html[#html+1] = '<fieldset class="advanced hide">'
		local delegateRestrict_attr = {
            group = {
                class = "advanced hide"
            },
            select = {
                class = "monitor-changes"
            }
        }
        html[#html+1] = ui_helper.createInputSelect(T"Delegation Restriction", "delegateRestriction", restrictions, content["delegateRestriction"], delegateRestrict_attr)

        local restrictOn_attr = {
            alert = {
                class = "alert-info monitor-delegateRestriction monitor-On"
            },
        }
        local restrictDynamic_attr = {
            alert = {
                class = "alert-info monitor-delegateRestriction monitor-Dynamic"
            },
        }
        local restrictOff_attr = {
            alert = {
                class = "alert-info monitor-delegateRestriction monitor-Off"
            },
        }
        html[#html+1] = ui_helper.createAlertBlock(T"In <strong>/64 prefix delegation restricted to lan mode</strong>, the gateway will only delegate the /64 IPv6 prefix to the lan interface, and not to the Guest or VLAN networks.", restrictOn_attr)
        html[#html+1] = ui_helper.createAlertBlock(T"In <strong>@dynamic mode</strong>, the gateway will only delegate the /64 IPv6 prefix to the LAN interface if there is @dynamic in the ppp username (Option only available for Internode). Otherwise it will attempt to delegate /64 IPv6 prefix to all the LAN and VLAN interfaces untill it runs out of prefixes.", restrictDynamic_attr)
        html[#html+1] = ui_helper.createAlertBlock(T"In <strong>Off mode</strong>, the gateway will attempt to delegate /64 IPv6 prefix to all the LAN and VLAN interfaces untill it runs out of prefixes.", restrictOff_attr)
		html[#html+1] = '</fieldset>'
    end

    ngx.print(html)
%>

</fieldset>
