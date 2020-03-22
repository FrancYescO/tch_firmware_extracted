--pretranslated: do not change this file
 
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
local hosts_ac_list = {
    {"", ""},
    {"any", T"any"},
}
for k, v in pairs(hosts_ac) do
    hosts_ac_list[#hosts_ac_list + 1] ={v,k}
end

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
    {"lax", T"<strong>Disabled</strong>"},
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
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vSIP = post_helper.validateStringIsPort
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local vSIPR = post_helper.validateStringIsPortRange
local gVP = post_helper.getValidationPassword
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local gOV = post_helper.getOptionalValidation
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)
local vSIIv6 = post_helper.validateStringIsIPv6

local fw_valid = {
    fw_ping = vB,
    fw_level = gVIES(fw_levels),
    fw_outgoing_policy = gVIES(outgoingpolicy),
    fw_incoming_policy = gVIES(incomingpolicy),
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

local fwrules_ports =  {
    {"", ""},
    {"any", T"any"},
    {"20", T"FTP data (20)"},
    {"21", T"FTP control (21)"},
    {"22", T"SSH (22)"},
    {"23", T"Telnet (23)"},
    {"25", T"SMTP (25)"},
    {"53", T"DNS (53)"},
    {"67", T"BOOTP Server / DHCP (67)"},
    {"68", T"BOOTP Client / DHCP (68)"},
    {"69", T"TFTP (69)"},
    {"80", T"HTTP (80)"},
    {"110", T"POP3 (110)"},
    {"113", T"Ident IRC (113)"},
    {"119", T"NNTP (119)"},
    {"123", T"NTP (123)"},
    {"137", T"Netbios Name service (137)"},
    {"138", T"Netbios Datagram Service (138)"},
    {"139", T"Netbios Session Service (139)"},
    {"143", T"IMAP (143)"},
    {"161", T"SNMP (161)"},
    {"162", T"SNMP Trap (162)"},
    {"194", T"IRC (194)"},
    {"443", T"HTTPS (443)"},
    {"445", T"SMB file sharing (445)"},
    {"500", T"ISAKMP (500)"},
    {"546", T"DHCPv6 client (546)"},
    {"547", T"DHCPv6 server (547)"},
    {"554", T"RTSP (554)"},
    {"563", T"NNTPS (563)"},
    {"631", T"IPP/CUPS (631)"},
    {"989", T"FTPS data (989)"},
    {"990", T"FTPS control (990)"},
    {"993", T"IMAPS (993)"},
    {"994", T"IRCS (994)"},
    {"995", T"POP3S (995)"},
}


local fwrule_columns = {
  {
    header = "",
    name = "enabled",
    param = "enabled",
    type = "switch",
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
    default = "",
    type = "select",
    values = hosts_ac_list,
    attr = { select = { class="span2"} },
  },
  {
    header = T"Src port",
    name = "src_port",
    param = "src_port",
    default = "",
    type = "select",
    values = fwrules_ports,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Dst IP",
    name = "dest_ip",
    param = "dest_ip",
    default = "",
    type = "select",
    values = hosts_ac_list,
    attr = { select = { class="span2"} },
  },
  {
    header = T"Dst port",
    name = "dest_port",
    param = "dest_port",
    default = "",
    type = "select",
    values = fwrules_ports,
    attr = { select = { class="span1" } },
  },
}

local fwrule_options = {
    tableid = "fwrules",
    basepath = "rpc.network.firewall.userrule.@.",
    createMsg = T"Add new firewall rule",
}

local fwrule_valid = {
    enabled = vB,
    target = gVIES(fwrules_targets),
    protocol = gVIES(fwrules_protocols),
    src_ip = gOV(vSII),
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
    type = "switch",
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
    attr = { input = { class="span2", maxlength="39"} },
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
    attr = { input = { class="span2", maxlength="39"}, autocomplete = hosts_ac_v6 },
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
    createMsg = T"Add new IPv6 firewall rule",
}

local fwrule_v6_valid = {
    enabled_v6 = vB,
    target_v6 = gVIES(fwrules_targets),
    protocol_v6 = gVIES(fwrules_protocols_v6),
    src_ip_v6 = gOV(vSIIv6),
    src_port_v6 = gOV(vSIPR),
    dest_ip_v6 = gOV(vSIIv6),
    dest_port_v6 = gOV(vSIPR),
}


local fwrule_v6_data, fwrule_v6_helpmsg = post_helper.handleTableQuery(fwrule_v6_columns, fwrule_v6_options, fwrule_filter, fwrule_defaultObject, fwrule_v6_valid)
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Firewall", false, false))   ngx.print('\
\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/firewall-modal.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"Firewall level" ); ngx.print('</legend>\
\
');  
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
    html[#html+1] = ui_helper.createAlertBlock(T"In <strong>Disabled mode</strong>, the firewall will allow all outbound connections. It will also allow all incoming connections! Be careful!", lax_attr)

    local normal_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-normal"
        },
    }
    html[#html+1] = ui_helper.createAlertBlock(T"In <strong>normal mode</strong>, the firewall will allow all outbound connections. It will silently drop unknown incoming connections.", normal_attr)

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
  ngx.print('\
</fieldset>\
\
<fieldset>\
<legend>');  ngx.print( T"Firewall default behavior" ); ngx.print('</legend>\
\
');  
    local ping_attr = {
        group = {
            class = "monitor-fw_level monitor-normal monitor-high monitor-user"
        }
    }

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

    local html = {}
    html[#html+1] = ui_helper.createSwitch(T"Answer Internet ping", "fw_ping", content["fw_ping"], ping_attr)

    html[#html+1] = ui_helper.createInputSelect(T"Outgoing default policy", "fw_outgoing_policy", outgoingpolicy, content["fw_outgoing_policy"], outgoing_attr)
    html[#html+1] = ui_helper.createAlertBlock(T"The <strong>outgoing policy</strong> defines what is done with packets coming from the LAN devices toward the internet. Setting it to REJECT or DROP will forbid any internet traffic from the LAN unless explicitely allowed by a firewall rule.", info_attr)

    html[#html+1] = ui_helper.createInputSelect(T"Incoming default policy", "fw_incoming_policy", incomingpolicy, content["fw_incoming_policy"], outgoing_attr)
    html[#html+1] = ui_helper.createAlertBlock(T"The <strong>incoming policy</strong> defines what is done with packets destined to the gateway. They can be either REJECTED (the gateway will notify the sender they were rejected) or DROPPED (the gateway will silently discard those packets).", info_attr)

    ngx.print(html)
  ngx.print('\
\
\
</fieldset>\
\
<fieldset class="monitor-fw_level monitor-user">\
<legend>');  ngx.print( T"Firewall rules" ); ngx.print('</legend>\
\
');  
    local html = {}

    html[#html+1] =  ui_helper.createTable(fwrule_columns, fwrule_data, fwrule_options, nil, fwrule_helpmsg)

    ngx.print(html)
  ngx.print('\
\
<legend>');  ngx.print( T"Firewall rules for IPv6" ); ngx.print('</legend>\
');  
    local html = {}

    html[#html+1] =  ui_helper.createTable(fwrule_v6_columns, fwrule_v6_data, fwrule_v6_options, nil, fwrule_v6_helpmsg)

    ngx.print(html)
  ngx.print('\
\
</fieldset>\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
<script>\
(function() {\
    //by disableing the add new rule button, we prevent that the user start adding a rule, before the adapted firewall level user is saved.\
    //as this is a special case, we implement this here and not in actions.js\
    $(document).on("change", \'.modal select:not(.no-save):not(.disabled)\', function() {\
        $(".btn-table-new").addClass("disabled");\
    });\
    var src_port_input = $(\'<input name="src_port" class="span1 edit-input" type="text" maxlength="5">\');\
    var dest_port_input = $(\'<input name="dest_port" class="span1 edit-input" type="text" maxlength="5">\');\
    var src_ip_input = $(\'<input name="src_ip" class="span2 edit-input" type="text" maxlength="15">\');\
    var dest_ip_input = $(\'<input name="dest_ip" class="span2 edit-input" type="text" maxlength="15">\');\
    $(\'select[name="src_port"], select[name="dest_port"], select[name="src_ip"], select[name="dest_ip"]\').change(function() {\
        var value = $(this).find("option:selected").attr("value");\
        if (value == "any") {\
            var name = $(this).attr("name");\
            switch(name)\
            {\
                case "src_port":\
                    $(this).after(src_port_input);\
                    break;\
                case "dest_port":\
                    $(this).after(dest_port_input);\
                    break;\
                case "src_ip":\
                    $(this).after(src_ip_input);\
                    break;\
                case "dest_ip":\
                    $(this).after(dest_ip_input);\
                    break;\
                default:\
                    break;\
            }\
            $(this).remove();\
        }\
    } );\
}());\
</script>\
'); 