--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')
-- Process POST query

local ngx = ngx
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local portslist = require("portslist_helper")
local protolist = require("protolist_helper")
local hosts_ac, hosts_ac_v6 = require("web.uinetwork_helper").getAutocompleteHostsList(true)
local role = ngx.ctx.session:getrole()
local uniqueKey = post_helper.getRandomKey()
local untaint = string.untaint

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
    {"user", T"<strong>User defined</strong>"},
}

local fw_params = {
    fwv4_ping = "rpc.network.firewall.internetpingipv4",
    fwv6_ping = "rpc.network.firewall.internetpingipv6",
    fw_level = "rpc.network.firewall.mode",
    fw_outgoing_policy = "rpc.network.firewall.useroutgoingdefault",
    fw_incoming_policy = "rpc.network.firewall.userincomingdefault",
    fwv4_stealthmode = "rpc.network.firewall.stealthmode_ipv4",
    fwv6_stealthmode = "rpc.network.firewall.stealthmode_ipv6"
}

-- Retrieve GW IP + netmask for use by validation function
local ipdetails = {
    gw = "uci.network.interface.@lan.ipaddr",
    netmask = "uci.network.interface.@lan.netmask"
}
content_helper.getExactContent(ipdetails)

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean
local vSII = post_helper.validateStringIsIP
local gVIES = post_helper.getValidateInEnumSelect
local vSIPR = post_helper.validateStringIsPortRange
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)
local gAV = post_helper.getAndValidation
local vNES = post_helper.validateNonEmptyString
local gOV = post_helper.getOptionalValidation
local vIP4AS = post_helper.validateIPAndSubnet(4)
local vIP6AS = post_helper.validateIPAndSubnet(6)
local gDSM = post_helper.getDefaultSubnetMask
local netMaskToMask = post_helper.cidr2mask
local isNA = post_helper.isNetworkAddress
local vLXC = post_helper.validateLXC

local fw_valid = {
    fwv4_ping = vB,
    fwv6_ping = vB,
    fw_level = gVIES(fw_levels),
    fw_outgoing_policy = gVIES(outgoingpolicy),
    fw_incoming_policy = gVIES(incomingpolicy),
    fwv4_stealthmode = vB,
    fwv6_stealthmode = vB,
}

local content = post_helper.handleQuery(fw_params, fw_valid)

-- Firewall rules
local function fwrule_sort(rule1, rule2)
  return tonumber(rule1.paramindex) < tonumber(rule2.paramindex)
end

local fwrules_targets = {
    { "ACCEPT", "ACCEPT"},
    { "DROP", "DROP"},
    { "REJECT", "REJECT"},
}

--Traffic Policy decided based on source
--Incoming,if traffic is to be recieved by lan
--Outgoing,if traffic is sent from lan
local traffic_policy = {
    { "wan", "INCOMING"},
    { "lan", "OUTGOING"},
}

-- DSCP markings for firewall rules
-- First column denotes value to set
-- Second column denotes string displayed to user in drop-down
local fwrules_dscp = {
    {"", ""},
    {"-m dscp --dscp 0x0a", T"AF11" },
    {"-m dscp --dscp 0x0c", T"AF12" },
    {"-m dscp --dscp 0x0e", T"AF13" },
    {"-m dscp --dscp 0x12", T"AF21" },
    {"-m dscp --dscp 0x14", T"AF22" },
    {"-m dscp --dscp 0x16", T"AF23" },
    {"-m dscp --dscp 0x1a", T"AF31" },
    {"-m dscp --dscp 0x1c", T"AF32" },
    {"-m dscp --dscp 0x1e", T"AF33" },
    {"-m dscp --dscp 0x22", T"AF41" },
    {"-m dscp --dscp 0x24", T"AF42" },
    {"-m dscp --dscp 0x26", T"AF43" },
    {"-m dscp --dscp 0x08", T"CS1" },
    {"-m dscp --dscp 0x10", T"CS2" },
    {"-m dscp --dscp 0x18", T"CS3" },
    {"-m dscp --dscp 0x20", T"CS4" },
    {"-m dscp --dscp 0x28", T"CS5" },
    {"-m dscp --dscp 0x30", T"CS6" },
    {"-m dscp --dscp 0x38", T"CS7" },
    {"-m dscp --dscp 0x2e", T"EF" },
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
    header = T"TrafficType",
    name = "traffic",
    param = "src",
    default = "INCOMING",
    type = "select",
    values = traffic_policy,
    attr = { select = { class="span1", style="width: 100px" } },
  },
  {
    header = T"Action",
    name = "target",
    param = "target",
    default = "DROP",
    type = "select",
    values = fwrules_targets,
    attr = { select = { class="span1", style="width: 100px" } },
  },
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto",
    default = "tcp",
    type = "select",
    values = protolist.IPv4Protocol,
    attr = { select = { class="span1", style="width: 100px" } },
  },
  {
    header = T"Src IP/Subnet",
    name = "src_ip",
    param = "src_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="18"}, autocomplete = hosts_ac },
  },
  {
    header = T"Src port",
    name = "src_port",
    param = "src_port",
    type = "text",
    attr = { input = { class="span1", maxlength="11" }, autocomplete = portslist },
  },
  {
    header = T"Dst IP/Subnet",
    name = "dest_ip",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="18"}, autocomplete = hosts_ac },
  },
  {
    header = T"Dst port",
    name = "dest_port",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="11" }, autocomplete = portslist },
  },
  {
    header = T"DSCP",
    name = "dscp",
    param = "extra",
    default = "",
    type = "select",
    values = fwrules_dscp,
    attr = { select = { class="span1", style="width: 100px" } },
  },
}

local duplicatedErrMsg

--[[
   The following function used to validate the duplicate entries while adding or editing on firewall table.
   We will throw the duplicate error if any rows containing all 6 values below are duplicated
   Sample:- Protocol    Src IP       Src port      Dst IP         Dst port    DSCP
            TCP         192.168.1.1  1000          192.168.1.4    2000        AF23
            TCP         192.168.1.1  1000          192.168.1.5    2000        CS7
            UDP         192.168.1.1  1000          192.168.1.5    2001        AF23
            TCP         192.168.1.1  1000          192.168.1.5    2000        EF
            TCP/UDP     192.168.1.1  1000	   192.168.1.5	  2000	      AF23
   In above example the 4th and 2nd as well as 3rd and 5th rows are exactly duplicated. In this case we throw the error message as duplicated.
   If anyone of the value of row is different then we dont consider as duplicated row.
]]

--@function to validate Duplicate IPv4 Firewall Rules and IPv6 Firewall Rules.
--@param object All object details coming from each rows in GUI the above table fwrule_columns and below table fwrule_v6_columns.
--@return #boolean, #string
local function rulesDuplicateCheck(object)
  local value
  for k = 1, #object do
    for n = k+1, #object do
      if object[k][3] == object[n][3] or object[k][3] == "tcpudp" or object[n][3] == "tcpudp" then
        if object[k][4] == object[n][4] and object[k][5] == object[n][5] and object[k][6] == object[n][6] and object[k][7] == object[n][7] then
          -- string.find function applied to an object to differentiate between IPv4 or IPv6.
          value = string.find(object[k][4], ":") and string.find(object[n][4], ":") and string.find(object[k][6], ":") and string.find(object[k][6], ":")
          duplicatedErrMsg = T"Duplicate value"
          if value then
            return nil, {dest_port_v6 = duplicatedErrMsg}
          else
            return nil, {dest_port = duplicatedErrMsg}
          end
        end
      end
    end
  end
  return true
end

local fwrule_options = {
    tableid = "fwrules",
    basepath = "rpc.network.firewall.userrule.@.",
    createMsg = T"Add new IPv4 firewall rule",
    sorted = fwrule_sort,
    valid = rulesDuplicateCheck,
}

local function removeSpace(validation)
  return function(value, postdata, key)
  local success,msg
  if value and value ~= "" then
    value = string.gsub(value," " ,"")
    postdata[key] = value
    success,msg = validation(value)
  end
  return success,msg
 end
end

local function getIPAndMask(value)
  return value:match("^([^/]+)/?(%d*)$")
end

local function srcdestDuplicateCheck(value, object)
  if object.tableid == "fwrules" then
    if getIPAndMask(object.dest_ip) == getIPAndMask(object.src_ip) then
      return nil, T"Source IP cannot be same as Destination IP"
    end
  elseif object.tableid == "fwrules_v6" then
    if getIPAndMask(object.dest_ip_v6) == getIPAndMask(object.src_ip_v6) then
      return nil, T"Source IP cannot be same as Destination IP"
    end
  end
  return true
end

local function validateWANIP(value, object, key)
  local ipAddress, netMask = getIPAndMask(value)
  if netMask == "" then
    --To add default subnet mask to the IPv4 Network Address if not explicitly mentioned.
    netMask = gDSM(ipAddress)
    if netMask and isNA(ipAddress, netMaskToMask(netMask)) then
      object[key] = value .. "/" .. netMask
    end
  end
  object["localdevmask"] = netMask and netMaskToMask(netMask)
  local retVal, msg = post_helper.advancedIPValidation(ipAddress, object, key)
  if retVal then
    retVal, msg = post_helper.reservedIPValidation(ipAddress)
  end
  return retVal, msg
end

local function validateLANIP(value, object, key)
  local ipAddress, netMask = getIPAndMask(value)
  local retVal, msg = vSIDIP(ipAddress)
  if retVal then
    retVal, msg = post_helper.reservedIPValidation(ipAddress)
  end
  return retVal, msg
end

---@function to validate Source IP only
---when the traffic is outgoing, Source IP should be in range of gateway subnet
---if it is outgoing, Source IP can be any public(wan) IP
local function validSIPCheck(srcIP, postData, key)
  if postData.traffic == "lan" then
    return validateLANIP(srcIP, postData, key)
  else
    return validateWANIP(srcIP, postData, key)
  end
end

---@function to validate Destination IP only
---when the traffic is incoming, Destination IP should be in range of gateway subnet
---if it is outgoing, Destination IP can be any public(wan) IP
local function validDIPCheck(destIP, postData, key)
  if postData.traffic == "wan" then
    return validateLANIP(destIP, postData, key)
  else
    return validateWANIP(destIP, postData, key)
  end
end

local fwrule_defaultObject = {}

---@function to validate traffic type
---When traffic is outgoing,src and dest has to be
---lan and wan respectively, when the traffic is incoming
---src and dest should be vice versa
local function setTrafficEndPoints(trafficType)
  if untaint(trafficType) == "lan" then
    fwrule_defaultObject.src = "lan"
    fwrule_defaultObject.dest = "wan"
  else
    fwrule_defaultObject.src = "wan"
    fwrule_defaultObject.dest = "lan"
  end
  return true
end

local fwrule_valid = {
    enabled = vB,
    traffic = setTrafficEndPoints,
    target = gVIES(fwrules_targets),
    protocol = gVIES(protolist.IPv4Protocol),
    src_ip = gAV(vIP4AS, validSIPCheck, vLXC),
    src_port = gOV(vSIPR),
    dest_ip = gAV(vIP4AS, validDIPCheck, srcdestDuplicateCheck, vLXC),
    dest_port = gOV(vSIPR),
    dscp = gVIES(fwrules_dscp),
}

-- PING WHITELIST RULES START

-- select list for icmp-type
local icmpTypeList = { {"echo-request", "echo-request"}, }

-- pingrule handleTableQuery parameter to match columns to rpc table data
local fwrulev4_ping_columns = {
  {
    header = T"Enabled",
    name = "enabled",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Source IP",
    name = "src_ip",
    param = "src_ip",
    type = "text",
    unique = true,
    attr = { input = { class="span3", maxlength="39" }, },
  },
  {
    header = T"icmp-type",
    name = "icmp_type",
    param = "icmp_type.@1.value",
    default = "echo-request",
    type = "select",
    values = icmpTypeList,
    attr = { select = { class="span2", readonly="true"}, },
  },
  {
    header = "",
    name = "family",
    param = "family",
    type = "hidden",
    default = "ipv4",
  },
  {
    header = "",
    name = "proto",
    param = "proto.@1.value",
    default = "icmp",
    type = "hidden",
  },
}

local fwrulev6_ping_columns = {
  {
    header = T"Enabled",
    name = "enabled",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Source IP",
    name = "src_ip",
    param = "src_ip",
    type = "text",
    unique = true,
    attr = { input = { class="span3", maxlength="39" }, },
  },
  {
    header = T"icmp-type",
    name = "icmp_type",
    param = "icmp_type.@1.value",
    default = "echo-request",
    type = "select",
    values = icmpTypeList,
    attr = { select = { class="span2", readonly="true"}, },
  },
  {
     header = "",
     name = "family",
     param = "family",
     type = "hidden",
     default = "ipv6",
  },
  {
    header = "",
    name = "proto",
    param = "proto.@1.value",
    default = "icmp",
    type = "hidden",
  },
}

-- pingrule handleTableQuery parameter for query and display
local fwrulev4_ping_options = {
    tableid = "fwv4_ping_rules",
    basepath = "uci.firewall.rule.@.",
    objectName  = uniqueKey,
    addNamedObject = true,
    createMsg = T"Add new IPv4 Ping WhiteList rule",
    -- Only allow table edits if overall remote ping is disabled when the page
    -- is loaded. If you disable remote ping your must save the change before
    -- editing is enabled. This is a GUI problem work around.
    canEdit = content["fwv4_ping"] == "0" and (role ~= "admin"),
    canAdd = content["fwv4_ping"] == "0" and (role ~= "admin"),
    canDelete = content["fwv4_ping"] == "0" and (role ~= "admin"),
}

local fwrulev6_ping_options = {
    tableid = "fwv6_ping_rules",
    basepath = "uci.firewall.rule.@.",
    objectName  = uniqueKey,
    addNamedObject = true,
    createMsg = T"Add new IPv6 Ping WhiteList rule",
    -- Only allow table edits if overall remote ping is disabled when the page
    -- is loaded. If you disable remote ping your must save the change before
    -- editing is enabled. This is a GUI problem work around.
    canEdit = content["fwv6_ping"] == "0" and (role ~= "admin"),
    canAdd = content["fwv6_ping"] == "0" and (role ~= "admin"),
    canDelete = content["fwv6_ping"] == "0" and (role ~= "admin"),
}

-- pingrule handleTableQuery parameter filter callback to only show ping
-- whitelist rules
-- return true if entry should be displayed
local function fwrulev4_ping_filter(data)
    if ( string.sub(data.name, 1, string.len("WhiteList")) == "WhiteList" ) and data["family"] == "ipv4" then
        return true
    end

    return false
end

local function fwrulev6_ping_filter(data)
    if ( string.sub(data.name, 1, string.len("WhiteList")) == "WhiteList" ) and data["family"] == "ipv6" then
        return true
    end

    return false
end

-- ipv6 handleTableQuery parameter for default values when adding entry
local fwrule_ping_defaultObject = {
    src = "wan",
    target = "ACCEPT",
    name = "WhiteList",
}

-- pingrule handleTableQuery parameter to check validity of new entry values
-- every editable column needs a validity check function
local function validateIPv4(value, object, key)
    if string.find(value, ":") then
        return nil, T"Invalid IPv4 Address"
    end
    --object["family"] = "ipv4"
    return vSII(value, object, key)
end

local fwrulev4_ping_valid = {
    enabled = vB,
    src_ip = gAV(vNES, removeSpace(validateIPv4), vLXC),
    icmp_type = gVIES(icmpTypeList),
}

local fwrulev6_ping_valid = {
    enabled = vB,
    src_ip = gAV(vNES, removeSpace(vIP6AS)),
    icmp_type = gVIES(icmpTypeList),
}

local fwrulev4_ping_data, fwrulev4_ping_helpmsg = post_helper.handleTableQuery(fwrulev4_ping_columns, fwrulev4_ping_options, fwrulev4_ping_filter, fwrule_ping_defaultObject, fwrulev4_ping_valid)
local fwrulev6_ping_data, fwrulev6_ping_helpmsg = post_helper.handleTableQuery(fwrulev6_ping_columns, fwrulev6_ping_options, fwrulev6_ping_filter, fwrule_ping_defaultObject, fwrulev6_ping_valid)

-- PING WHITELIST RULES END

local fwrule_data, fwrule_helpmsg = post_helper.handleTableQuery(fwrule_columns, fwrule_options, nil, fwrule_defaultObject, fwrule_valid)

if duplicatedErrMsg then
  fwrule_helpmsg.protocol = duplicatedErrMsg
  fwrule_helpmsg.src_ip = duplicatedErrMsg
  fwrule_helpmsg.src_port = duplicatedErrMsg
  fwrule_helpmsg.dest_ip = duplicatedErrMsg
  fwrule_helpmsg.dest_port = duplicatedErrMsg
  fwrule_helpmsg.dscp = duplicatedErrMsg
  duplicatedErrMsg = nil
end

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
    header = T"TrafficType",
    name = "traffic_v6",
    param = "src",
    default = "INCOMING",
    type = "select",
    values = traffic_policy,
    attr = { select = { class="span1", style="width: 100px" } },
  },
  {
    header = T"Action",
    name = "target_v6",
    param = "target",
    default = "DROP",
    type = "select",
    values = fwrules_targets,
    attr = { select = { class="span1", style="width: 100px" } },
  },
  {
    header = T"Protocol",
    name = "protocol_v6",
    param = "proto",
    default = "tcp",
    type = "select",
    values = protolist.IPv6Protocol,
    attr = { select = { class="span1", style="width: 100px" } },
  },
  {
    header = T"Src IP/Subnet",
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
    header = T"Dst IP/Subnet",
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
  {
    header = T"DSCP",
    name = "dscp_v6",
    param = "extra",
    default = "",
    type = "select",
    values = fwrules_dscp,
    attr = { select = { class="span1", style="width: 100px" } },
  },
}

local fwrule_v6_options = {
    tableid = "fwrules_v6",
    basepath = "rpc.network.firewall.userrule_v6.@.",
    createMsg = T"Add new IPv6 firewall rule",
    sorted = fwrule_sort,
    valid = rulesDuplicateCheck,
}

local fwrule_v6_valid = {
    enabled_v6 = vB,
    traffic_v6 = setTrafficEndPoints,
    target_v6 = gVIES(fwrules_targets),
    protocol_v6 = gVIES(protolist.IPv6Protocol),
    src_ip_v6 = gOV(vIP6AS),
    src_port_v6 = gOV(vSIPR),
    dest_ip_v6 = gAV(vIP6AS, srcdestDuplicateCheck),
    dscp_v6 = gVIES(fwrules_dscp),
}

local fwrule_v6_data, fwrule_v6_helpmsg = post_helper.handleTableQuery(fwrule_v6_columns, fwrule_v6_options, nil, fwrule_defaultObject, fwrule_v6_valid)

if duplicatedErrMsg then
  fwrule_v6_helpmsg.protocol_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.src_ip_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.src_port_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.dest_ip_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.dest_port_v6 = duplicatedErrMsg
  fwrule_v6_helpmsg.dscp_v6 = duplicatedErrMsg
end
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
    local fwallmsg_visible_status = {
        lax = "monitor-hidden-fw_level",
        normal = "monitor-hidden-fw_level",
        high = "monitor-hidden-fw_level",
        user = "monitor-hidden-fw_level"
    }
    if content["fw_level"] == "lax" then
        fwallmsg_visible_status["lax"]=""
    elseif content["fw_level"] == "normal" then
        fwallmsg_visible_status["normal"]=""
    elseif content["fw_level"] == "high" then
        fwallmsg_visible_status["high"]=""
    elseif content["fw_level"] == "user" then
        fwallmsg_visible_status["user"]=""
    end
    local fwlevel_attr = {
        group = {
            class = ""
        },
        select = {
            class = "monitor-changes"
        }
    }
    local lax_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-lax " .. fwallmsg_visible_status["lax"]
        },
    }
    local normal_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-normal " .. fwallmsg_visible_status["normal"]
        },
    }
    local high_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-high " .. fwallmsg_visible_status["high"]
        },
    }
    local user_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-user " .. fwallmsg_visible_status["user"]
        },
    }
    local ipv4_stealthmode_attr = {
        alert = {
            class = "alert-info monitor-fwv4_stealthmode monitor-1"
        },
    }
    local ipv6_stealthmode_attr = {
        alert = {
            class = "alert-info monitor-fwv6_stealthmode monitor-1"
        },
    }

    -- To monitor the stealthmode enable switch
    local switch_class_enablemode = {
        input = {
            class = "monitor-changes",
        }
    }

    ngx.print(
        ui_helper.createSliderSelect(T"Level", "fw_level", fw_levels, content["fw_level"], fwlevel_attr),
        ui_helper.createAlertBlock(T"In <strong>low mode</strong>, firewall allows all outbound connections and rejects unknown incoming connections but acknowledges presence of the gateway.", lax_attr),
        ui_helper.createAlertBlock(T"In <strong>medium mode</strong>, firewall allows all outbound connections and silently drops unknown incoming connections.", normal_attr),
        ui_helper.createAlertBlock(T"In <strong>high mode</strong>, firewall allows outgoing connections to HTTP, HTTPS, SMTP, POP3, IMAP, SSH services and silently drops unknown incoming connections.", high_attr),
        ui_helper.createAlertBlock(T"In <strong>user mode</strong>, individual firewall rules may be configured as well as the default behavior.", user_attr)
    )
    ngx.print(ui_helper.createSwitch(T"IPv4 Stealth Mode ", "fwv4_stealthmode", content["fwv4_stealthmode"], switch_class_enablemode))
    ngx.print(ui_helper.createAlertBlock(T"<strong>Enabling this will overwrite InternetIPv4 ping selections</strong>,firewall will drop all ICMPv4 services for incoming connections",ipv4_stealthmode_attr))
    ngx.print(ui_helper.createSwitch(T"IPv6 Stealth Mode ", "fwv6_stealthmode", content["fwv6_stealthmode"], switch_class_enablemode))
    ngx.print(ui_helper.createAlertBlock(T"<strong>Enabling this will overwrite InternetIPv6 ping selections</strong>,firewall will drop all ICMPv6 services for incoming connections",ipv6_stealthmode_attr))
  ngx.print('\
</fieldset>\
\
<fieldset>\
<legend>');  ngx.print( T"Firewall default behavior" ); ngx.print('</legend>\
\
');  
    local outgoing_attr = {
        group = {
            class = "monitor-fw_level monitor-user " .. fwallmsg_visible_status["user"]
        }
    }

    local info_attr = {
        alert = {
            class = "alert-info monitor-fw_level monitor-user " .. fwallmsg_visible_status["user"]
        },
    }

    -- To monitor the ping enable switch
    local switch_class_enable = {
        input = {
            class = "monitor-changes",
        }
    }

    -- enable/disable the pingAllow table
     local pingrespv4_table_attr = {
        group = {
           class = "monitor-fwv4_ping monitor-0"
        }
     }

      local pingrespv6_table_attr = {
         group = {
            class = "monitor-fwv6_ping monitor-0"
         }
      }

    -- enable/disable the pingAllow text
    local pingrespv4_alert_attr = {
        alert = {
            class = "alert-info monitor-fwv4_ping monitor-0"
        },
    }

    local pingrespv6_alert_attr = {
        alert = {
            class = "alert-info monitor-fwv6_ping monitor-0"
        },
    }


    ngx.print(ui_helper.createSwitch(T"Answer All IPv4 Internet pings", "fwv4_ping", content["fwv4_ping"], switch_class_enable))
    ngx.print(ui_helper.createAlertBlock(T"Answer only these selected Internet IPv4 pings", pingrespv4_alert_attr))
    ngx.print(ui_helper.createTable(fwrulev4_ping_columns, fwrulev4_ping_data, fwrulev4_ping_options, pingrespv4_table_attr, fwrulev4_ping_helpmsg))

    ngx.print(ui_helper.createSwitch(T"Answer All IPv6 Internet pings", "fwv6_ping", content["fwv6_ping"], switch_class_enable))
    ngx.print(ui_helper.createAlertBlock(T"Answer only these selected Internet IPv6 pings", pingrespv6_alert_attr))
    ngx.print(ui_helper.createTable(fwrulev6_ping_columns, fwrulev6_ping_data, fwrulev6_ping_options, pingrespv6_table_attr, fwrulev6_ping_helpmsg))
  ngx.print('\
        <legend></legend>\
');  

    ngx.print(
        ui_helper.createInputSelect(T"Outgoing default policy", "fw_outgoing_policy", outgoingpolicy, content["fw_outgoing_policy"], outgoing_attr),
        ui_helper.createAlertBlock(T"The <strong>outgoing policy</strong> defines what is done with packets coming from the LAN devices toward the internet. Setting it to REJECT or DROP will forbid any internet traffic from the LAN unless explicitly allowed by a firewall rule.", info_attr),
        ui_helper.createInputSelect(T"Incoming default policy", "fw_incoming_policy", incomingpolicy, content["fw_incoming_policy"], outgoing_attr),
        ui_helper.createAlertBlock(T"The <strong>incoming policy</strong> defines what is done with packets destined to the gateway. They can be either REJECTED (the gateway will notify the sender they were rejected) or DROPPED (the gateway will silently discard those packets).", info_attr)
    )
  ngx.print('\
\
\
</fieldset>\
\
<fieldset class="monitor-fw_level monitor-user ');  ngx.print(fwallmsg_visible_status["user"]); ngx.print('">\
<legend>');  ngx.print( T"IPv4 Firewall Rules" ); ngx.print('</legend>\
');  
    ngx.print(ui_helper.createTable(fwrule_columns, fwrule_data, fwrule_options, nil, fwrule_helpmsg))
  ngx.print('\
\
<legend>');  ngx.print( T"IPv6 Firewall Rules" ); ngx.print('</legend>\
');  
    ngx.print(ui_helper.createTable(fwrule_v6_columns, fwrule_v6_data, fwrule_v6_options, nil, fwrule_v6_helpmsg))
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
    //by disabling the add new rule button, we prevent that the user start adding a rule, before the adapted firewall level user is saved.\
    //as this is a special case, we implement this here and not in actions.js\
    $(document).on("change", \'.modal select:not(.no-save):not(.disabled)\', function() {\
        $(".btn-table-new").addClass("disabled");\
    });\
}());\
var portLessProtocol = {};\
');  for _, v in ipairs(protolist.portless_proto) do   ngx.print('\
   portLessProtocol["');  ngx.print(v[1]); ngx.print('"] = true;\
');  end  ngx.print('\
\
if(portLessProtocol[$("#protocol").val()]){\
   $("#src_port, #dest_port").attr("readonly","true");\
}\
\
if(portLessProtocol[$("#protocol_v6").val()]){\
   $("#src_port_v6, #dest_port_v6").attr("readonly","true");\
}\
\
$("#protocol, #protocol_v6").on("change", function(){\
   if(portLessProtocol[this.value]){\
      $("#src_port, #dest_port").val("");\
      $("#src_port, #dest_port").attr("readonly","true");\
      $("#src_port_v6, #dest_port_v6").val("");\
      $("#src_port_v6, #dest_port_v6").attr("readonly","true");\
   }\
   else{\
      $("#src_port, #dest_port").removeAttr("readonly");\
      $("#src_port_v6, #dest_port_v6").removeAttr("readonly");\
   }\
});\
</script>\
'); 