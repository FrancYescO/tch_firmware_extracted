<%
-- Localization
gettext.textdomain('webui-core')
-- Process POST query

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local portslist = require("portslist_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac, hosts_ac_v6 = uinetwork.getAutocompleteHostsList()
local pairs, table = pairs, table

local outgoingpolicy = {
    {"ACCEPT", T"ACCEPT"},
    {"DROP", T"DROP"},
    {"REJECT", T"REJECT"},
}

local incomingpolicy = {
    {"DROP", T"DROP"},
    {"REJECT", T"REJECT"},
}

local fw_levels = {
    {"lax", T"<strong>Low</strong>"},
    {"normal", T"<strong>Normal</strong>"},
    {"high", T"<strong>High</strong>"},
    {"user", T"<strong>User defined</strong>"}
}

local fw_params = {
    fw_ping = "rpc.network.firewall.internetping",
    fw_level = "rpc.network.firewall.mode",
    fw_outgoing_policy = "rpc.network.firewall.useroutgoingdefault",
    fw_incoming_policy = "rpc.network.firewall.userincomingdefault",
}

-- Retrieve GW IP + netmask for use by validation function
local ipdetails = {
    gw = "uci.network.interface.@lan.ipaddr",
    netmask = "uci.network.interface.@lan.netmask"
}
content_helper.getExactContent(ipdetails)

-- Shortcuts to validation helpers to make lines shorter
local gVIES = post_helper.getValidateInEnumSelect
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vSIP = post_helper.validateStringIsPort
local vSIPR = post_helper.validateStringIsPortRange
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local gVP = post_helper.getValidationPassword
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local gOV = post_helper.getOptionalValidation
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)
local vSIIv6 = post_helper.validateStringIsIPv6

local fw_valid = {
    fw_ping = post_helper.getValidateCheckboxSwitch(),
    fw_level = gVIES(fw_levels),
    fw_outgoing_policy = gVIES(outgoingpolicy),
}

local content,fw_helpmsg = post_helper.handleQuery(fw_params, fw_valid)

-- Firewall rules
local fwrules_targets = {
    { "ACCEPT", "ACCEPT"},
    { "DROP", "DROP"},
    { "REJECT", "REJECT"},
}

local fwrules_protocols = {
    { "tcp", T"TCP"},
    { "udp", T"UDP"},
    { "tcpudp", T"TCP/UDP"},
    { "udplite", T"UDPLite"},
    { "icmp", T"ICMP"},
    { "esp", T"ESP"},
    { "ah", T"AH"},
    { "sctp", T"SCTP"},
    { "all", T"all"},
}

local fwrule_columns = {
  {
    header = "",
    name = "enabled",
    param = "enabled",
    type = "checkboxswitch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Action",
    name = "target",
    param = "target",
    default = "DROP",
    type = "select",
    values = fwrules_targets,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto",
    default = "tcp",
    type = "select",
    values = fwrules_protocols,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Src IP",
    name = "src_ip",
    param = "src_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"}, autocomplete = hosts_ac },
  },
  {
    header = T"Src port",
    name = "src_port",
    param = "src_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
  {
    header = T"Dst IP",
    name = "dest_ip",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"} },
  },
  {
    header = T"Dst port",
    name = "dest_port",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
}

local fwrule_options = {
    tableid = "fwrules",
    basepath = "rpc.network.firewall.userrule.@.",
    createMsg = "Add new firewall rule",
}

local fwrule_valid = {
    enabled = post_helper.getValidateCheckboxSwitch(),
    target = gVIES(fwrules_targets),
    protocol = gVIES(fwrules_protocols),
    src_ip = gOV(vSIDIP),
    src_port = gOV(vSIPR),
    dest_ip = gOV(vSII),
    dest_port = gOV(vSIPR),
}

local fwrule_filter = nil
local fwrule_defaultObject = {
    src = "lan",
    dest = "wan"
}

local fwrule_data, fwrule_helpmsg = post_helper.handleTableQuery(fwrule_columns, fwrule_options, fwrule_filter, fwrule_defaultObject, fwrule_valid)

local fwrules_protocols_v6 = {
    { "tcp", T"TCP"},
    { "udp", T"UDP"},
    { "tcpudp", T"TCP/UDP"},
    { "udplite", T"UDPLite"},
    { "icmpv6", T"ICMPv6"},
    { "esp", T"ESP"},
    { "ah", T"AH"},
    { "sctp", T"SCTP"},
    { "all", T"all"},
}

local fwrule_v6_columns = {
  {
    header = "",
    name = "enabled_v6",
    param = "enabled",
    type = "checkboxswitch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Action",
    name = "target_v6",
    param = "target",
    default = "DROP",
    type = "select",
    values = fwrules_targets,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Protocol",
    name = "protocol_v6",
    param = "proto",
    default = "tcp",
    type = "select",
    values = fwrules_protocols_v6,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Src IP",
    name = "src_ip_v6",
    param = "src_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="39"}, autocomplete = hosts_ac_v6 },
  },
  {
    header = T"Src port",
    name = "src_port_v6",
    param = "src_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
  {
    header = T"Dst IP",
    name = "dest_ip_v6",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="39"} },
  },
  {
    header = T"Dst port",
    name = "dest_port_v6",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" }, autocomplete = portslist },
  },
}

local fwrule_v6_options = {
    tableid = "fwrules_v6",
    basepath = "rpc.network.firewall.userrule_v6.@.",
    createMsg = "Add new IPv6 firewall rule",
}

local fwrule_v6_valid = {
    enabled_v6 = post_helper.getValidateCheckboxSwitch(),
    target_v6 = gVIES(fwrules_targets),
    protocol_v6 = gVIES(fwrules_protocols_v6),
    src_ip_v6 = gOV(vSIIv6),
    src_port_v6 = gOV(vSIPR),
    dest_ip_v6 = gOV(vSIIv6),
    dest_port_v6 = gOV(vSIPR),
}

local fwrule_v6_data, fwrule_v6_helpmsg = post_helper.handleTableQuery(fwrule_v6_columns, fwrule_v6_options, fwrule_filter, fwrule_defaultObject, fwrule_v6_valid)

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
%>

<%=ui_helper.createHeader(T"Firewall", true, false, nil, help_link) %>

<div class="modal-body update">
<form class="form-horizontal" method="post" action="modals/firewall-modal.lp">
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<fieldset>
<legend><%= T"Firewall level" %></legend>

<%
    local html = {}

    local fwlevel_attr = {
        group = {
            class = ""
        },
        select = {
            class = "monitor-changes"
        }
    }
    html[#html+1] = ui_helper.createSliderSelect(T"Level", "fw_level", fw_levels, content["fw_level"], fwlevel_attr)

    local lax_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-lax"
        },
    }
    html[#html+1] = ui_helper.createAlertBlock(T"In <strong>low mode</strong>, the firewall will allow all outbound connections. It will reject unknown incoming connections but acknowledge the presence of the gateway.", lax_attr)

    local normal_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-normal"
        },
    }
    html[#html+1] = ui_helper.createAlertBlock(T"In <strong>normal mode</strong>, the firewall will allow all outbount connections. It will silently drop unknown incoming connections.", normal_attr)

    local high_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-high"
        },
    }
    html[#html+1] = ui_helper.createAlertBlock(T"In <strong>high mode</strong>, the firewall will allow outgoing connections to the following services: HTTP, HTTPS, SMTP, POP3, IMAP, SSH. It will silently drop unknown incoming connections.", high_attr)

    local user_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-user"
        },
    }
    html[#html+1] = ui_helper.createAlertBlock(T"In <strong>user mode</strong>, you can configure each individual rule of the firewall as well as the default behavior.", user_attr)

    ngx.print(html)
%>
</fieldset>

<fieldset">
<legend><%= T"Firewall default behavior" %></legend>

<%
    local html = {}
    html[#html+1] = ui_helper.createCheckboxSwitch(T"Answer Internet ping", "fw_ping", content["fw_ping"])

    local outgoing_attr = {
        group = {
            class = "monitor-fw_level monitor-user"
        }
    }

    local info_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-user"
        },
    }

    html[#html+1] = ui_helper.createInputSelect(T"Outgoing default policy", "fw_outgoing_policy", outgoingpolicy, content["fw_outgoing_policy"], outgoing_attr)
    html[#html+1] = ui_helper.createAlertBlock(T"The <strong>outgoing policy</strong> defines what is done with packets coming from the LAN devices toward the internet. Setting it to REJECT or DROP will forbid any internet traffic from the LAN unless explicitely allowed by a firewall rule.", info_attr)

    html[#html+1] = ui_helper.createInputSelect(T"Incoming default policy", "fw_incoming_policy", incomingpolicy, content["fw_incoming_policy"], outgoing_attr)
    html[#html+1] = ui_helper.createAlertBlock(T"The <strong>incoming policy</strong> defines what is done with packets destined to the gateway. They can be either REJECTED (the gateway will notify the sender they were rejected) or DROPPED (the gateway will silently discard those packets).", info_attr)

    ngx.print(html)
%>


</fieldset>
</form>

<form class="form-horizontal" method="post" action="modals/firewall-modal.lp">
<fieldset class="monitor-fw_level monitor-user">
<legend><%= T"Firewall rules" %></legend>

<%
    local html = {}

    html[#html+1] =  ui_helper.createTable(fwrule_columns, fwrule_data, fwrule_options, nil, fwrule_helpmsg)

    ngx.print(html)
%>

<legend><%= T"Firewall rules for IPv6" %></legend>
<%
    local html = {}

    html[#html+1] =  ui_helper.createTable(fwrule_v6_columns, fwrule_v6_data, fwrule_v6_options, nil, fwrule_v6_helpmsg)

    ngx.print(html)
%>

</fieldset>
</form>
</div>

<% ngx.print(ui_helper.createFooter()) %>
