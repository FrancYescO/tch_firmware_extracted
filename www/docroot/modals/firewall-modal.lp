--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')
-- Process POST query

local ngx = ngx
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local portslist = require("portslist_helper")
local protolist = require("protolist_helper")
local hosts_ac, hosts_ac_v6 = require("web.uinetwork_helper").getAutocompleteHostsList(true)
local role = ngx.ctx.session:getrole()
local uniqueKey = post_helper.getRandomKey()
local untaint, format = string.untaint, string.format
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Firewall", "firewall")
local new_dest_v4, new_dest_v6 = {}, {}
for k,v in pairs(hosts_ac) do
  new_dest_v4[#new_dest_v4+1] = {v,k}
end

for k,v in pairs(hosts_ac_v6) do
  new_dest_v6[#new_dest_v6+1] = {v,k}
end

local fw_rules = content_helper.convertResultToObject("uci.firewall.rule.",proxy.get("uci.firewall.rule."))
local function addWhiteList()
  local value = "1"
  for _, v in pairs(fw_rules) do
    if ( string.sub(v.name, 1, string.len("WhiteList")) == "WhiteList" ) then
      value = value +1
    end
  end
  return value
end
local numList = addWhiteList()


local trafficTypeValue = post_helper.isFeatureEnabled("trafficType", role) and "false" or "true"
local dscpValue = post_helper.isFeatureEnabled("dscpValue", role) and "false" or "true"
local sipAlg = post_helper.isFeatureEnabled("sipAlg", role) and 1 or 0
local protocollist = post_helper.isFeatureEnabled("protocollist", role) and "false" or "true"

local outgoingpolicy = {
  {"ACCEPT", T"ACCEPT"},
  {"DROP", T"DROP"},
  {"REJECT", T"REJECT"}
}

local incomingpolicy = {
  {"DROP", T"DROP"},
  {"REJECT", T"REJECT"}
}

local fw_levels = {
  {"lax", T"<strong>Low</strong>"},
  {"normal", T"<strong>Medium</strong>"},
  {"high", T"<strong>High</strong>"}
}
-- Only in TI, User level is restricted to Engineer view
if post_helper.isFeatureEnabled("firewallLevel", role) then
  fw_levels[#fw_levels + 1] = {"user", T"<strong>User</strong>"}
end

local updatedPortlist = {}
for service, port in pairs(portslist) do
  updatedPortlist[#updatedPortlist+1] = {port, service}
end

updatedPortlist[#updatedPortlist + 1] = {"custom", T"Custom"}
new_dest_v4[#new_dest_v4 + 1] = {"custom", T"Custom"}
new_dest_v6[#new_dest_v6 + 1] = {"custom", T"Custom"}

local function getConfPath(conf, type, name, opt)
  local pathConf = proxy.get(format("uci.%s.%s.", conf, type))
  local path = {}
  for pathConfKey, pathConfValue in pairs(pathConf) do
    if(pathConfValue.value == name) then
      path[#path+1] = pathConfValue.path .. opt
    end
  end
  return path
end

local alg_sip_paths = getConfPath("firewall_helpers","helper","sip","enable")

local fw_params = {
  fw_level = "rpc.network.firewall.mode",
  fw_outgoing_policy = "rpc.network.firewall.useroutgoingdefault",
  fw_incoming_policy = "rpc.network.firewall.userincomingdefault",
}

for algSipKey, algSipValue in ipairs(alg_sip_paths) do
  fw_params["fw_alg_sip_" .. algSipKey] = algSipValue
end

-- Retrieve GW IP + netmask for use by validation function
local ipdetails = {
  gw = "uci.network.interface.@lan.ipaddr",
  netmask = "uci.network.interface.@lan.netmask"
}
content_helper.getExactContent(ipdetails)

-- Shortcuts to validation helpers to make lines shorter
local validateBoolean = post_helper.validateBoolean
local validateString = post_helper.validateStringIsIP()
local validateEnumSelect = post_helper.getValidateInEnumSelect
local validatePortRange = post_helper.validateStringIsPortRange
local validateDeviceIPv4 = post_helper.getValidateStringIsDeviceIPv4
local validateIPDetails = validateDeviceIPv4(ipdetails.gw, ipdetails.netmask)
local validateAnd = post_helper.getAndValidation
local validateNonEmpty = post_helper.validateNonEmptyString
local validateOptional = post_helper.getOptionalValidation
local validateIPv4_Subnet = post_helper.validateIPAndSubnet(4)
local validateIPv6_Subnet = post_helper.validateIPAndSubnet(6)
local validateDefaultSubnet = post_helper.getDefaultSubnetMask
local netMaskToMask = post_helper.cidr2mask
local validateNetwork = post_helper.isNetworkAddress
local validateStringIPv6 = post_helper.validateStringIsIP(6)
local validateLXC = post_helper.validateLXC

local fw_valid = {
  fw_level = validateEnumSelect(fw_levels),
  fw_outgoing_policy = validateEnumSelect(outgoingpolicy),
  fw_incoming_policy = validateEnumSelect(incomingpolicy)
}

local function validateAlgSip(value, object, key)
  return post_helper.validateAlgSip(value, object, key, alg_sip_paths)
end

if post_helper.isFeatureEnabled("firewallDataParams", role) then
  fw_params["fwv4_ping"] = "rpc.network.firewall.internetpingipv4"
  fw_params["fwv6_ping"] = "rpc.network.firewall.internetpingipv6"
  fw_valid["fwv4_ping"] = validateBoolean
  fw_valid["fwv6_ping"] = validateBoolean
else --iinet
  fw_params["fw_ping"] = "rpc.network.firewall.internetping"
  fw_valid["fw_alg_sip_1"] = validateAlgSip
  fw_valid["fw_ping"] = validateBoolean
end

if post_helper.isFeatureEnabled("ipv6Firewall", role) then --ti
  fw_params["fw_ipv6"] = "Device.Firewall.X_000E50_EnableIPv6"
  fw_valid["fw_ipv6"] = validateBoolean
end

local content = post_helper.handleQuery(fw_params, fw_valid)

-- Firewall rules
local function fwrule_sort(rule1, rule2)
  return tonumber(rule1.paramindex) < tonumber(rule2.paramindex)
end

local fwrules_targets = {
  { "ACCEPT", "ACCEPT"},
  { "DROP", "DROP"},
  { "REJECT", "REJECT"}
}

local fwrules_protocols
if not post_helper.isFeatureEnabled("protocollist", role) then
  fwrules_protocols = {
    { "tcp", T"TCP" },
    { "udp", T"UDP" },
    { "tcpudp", T"TCP/UDP" },
    { "udplite", T"UDPLite" },
    { "icmp", T"ICMP" },
    { "esp", T"ESP" },
    { "ah", T"AH" },
    { "sctp", T"SCTP" },
    { "all", T"ALL" }
  }
else
  fwrules_protocols = protolist.IPv4Protocol
end

--Traffic Policy decided based on source
--Incoming, if traffic is to be recieved by lan
--Outgoing, if traffic is sent from lan
local traffic_policy = {
  { "wan", "INCOMING"},
  { "lan", "OUTGOING"}
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
  {"-m dscp --dscp 0x2e", T"EF" }
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
  { -- Not needed for ti
    header = T"TrafficType",
    name = "traffic",
    param = "src",
    default = "INCOMING",
    type = "select",
    values = traffic_policy,
    attr = { select = { class = "span1", style = "width: 100px" } }
  },
  {
    header = T"Action",
    name = "target",
    param = "target",
    default = "DROP",
    type = "select",
    values = fwrules_targets,
    attr = { select = { class = "span1", style = "width: 100px" } }
  },
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto",
    default = "tcp",
    type = "select",
    values = fwrules_protocols,
    attr = { select = { class = "span1", style = "width: 100px" } }
  },
  {
    header = T"Src IP/Subnet",
    name = "src_ip",
    param = "src_ip",
    type = "select",
    values = new_dest_v4,
    attr = { select = { class = "span2"}}
  },
  {
    header = T"Src port",
    name = "src_port",
    param = "src_port",
    type = "select",
    values = updatedPortlist,
    attr = { select = { class = "span1"}}
  },
  {
    header = T"Dst IP/Subnet",
    name = "dest_ip",
    param = "dest_ip",
    type = "select",
    values = new_dest_v4,
    attr = { select = { class = "span2"}}
  },
  {
    header = T"Dst port",
    name = "dest_port",
    param = "dest_port",
    type = "select",
    values = updatedPortlist,
    attr = { select = { class = "span1"}}
  },
  { -- Not needed for iinet
    header = T"DSCP",
    name = "dscp",
    param = "extra",
    default = "",
    type = "select",
    values = fwrules_dscp,
    attr = { select = { class = "span1", style = "width: 100px" } }
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

--@function to compare all the entries of two firewall rules
--@given in the loop of function rulesDuplicateCheck
local function isDuplicates(currentValue,newValue)
  for k, v in pairs(newValue) do
    if currentValue[k] ~= v and k ~= "protocol" then
      return false
    end
  end
  return true
end

--@function to validate Duplicate IPv4 Firewall Rules and IPv6 Firewall Rules.
--@param object All object details coming from each rows in GUI the above table fwrule_columns and below table fwrule_v6_columns.
--@return #boolean, #string
local function rulesDuplicateCheck(object)
  local value
  for duplicateValue = 1, #object do
    for duplicateNum = duplicateValue+1, #object do
      local currentValue = {
        trafficType = object[duplicateValue][2],
        protocol  = object[duplicateValue][4],
        s_ip = object[duplicateValue][5],
        s_port = object[duplicateValue][6],
        d_ip = object[duplicateValue][7],
        d_port = object[duplicateValue][8]
      }

      local newValue = {
        trafficType = object[duplicateNum][2],
        protocol = object[duplicateNum][4],
        s_ip = object[duplicateNum][5],
        s_port = object[duplicateNum][6],
        d_ip = object[duplicateNum][7],
        d_port =  object[duplicateNum][8]
      }
      --Condition check to check whether traffictype and protocol is same for the current index and new index
      if currentValue["protocol"] == newValue["protocol"] or currentValue["protocol"] == "tcpudp" or newValue["protocol"] == "tcpudp" then
      --Check to find whether all srcip, destip, srcport, destport of both indexes are equal
        if isDuplicates(currentValue,newValue) then
          -- string.find function applied to an object to differentiate between IPv4 or IPv6.
          value = string.find(object[duplicateValue][4], ":") and string.find(object[duplicateNum][4], ":") and string.find(object[duplicateValue][6], ":") and string.find(object[duplicateNum][6], ":")
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
  valid = rulesDuplicateCheck

}

if post_helper.isFeatureEnabled("firewallDataParams", role) then --Generic
  fwrule_options["sorted"] = fwrule_sort
  fwrule_options["createMsg"] = T"Add new IPv4 firewall rule"
else --iinet
  fwrule_options["createMsg"] = T"Add new firewall rule"
end

local function removeSpace(validation)
  return function(value, postdata, key)
  local success, msg
  if value and value ~= "" then
    value = string.gsub(value, " " , "")
    postdata[key] = value
    success, msg = validation(value)
  end
    return success, msg
  end
end

local function getIPAndMask(value)
  return value:match("^([^/]+)/?(%d*)$")
end

local function srcdestDuplicateCheck(value, object)
  if object.tableid == "fwrules" and getIPAndMask(object.dest_ip) == getIPAndMask(object.src_ip) and object.dest_ip ~= "" then
    return nil, T"Source IP cannot be same as Destination IP"
  elseif object.tableid == "fwrules_v6" and getIPAndMask(object.dest_ip_v6) == getIPAndMask(object.src_ip_v6) and object.dest_ip_v6 ~= "" then
    return nil, T"Source IP cannot be same as Destination IP"
  end
  return true
end

---@function to validate Source IP only
---when the traffic is outgoing, Source IP should be in range of gateway subnet
---if it is outgoing, Source IP can be any public(wan) IP
local function validSIPCheck(srcIP, postData, key)
  if postData.traffic == "lan" then
    return post_helper.validateLANIP(srcIP, postData, key)
  else
    return post_helper.validateWANIP(srcIP, postData, key)
  end
end

---@function to validate Destination IP only
---when the traffic is incoming, Destination IP should be in range of gateway subnet
---if it is outgoing, Destination IP can be any public(wan) IP
local function validDIPCheck(destIP, postData, key)
  if postData.traffic == "wan" then
    return post_helper.validateLANIP(destIP, postData, key)
  else
    return post_helper.validateWANIP(destIP, postData, key)
  end
end

local fwrule_defaultObject = {}

---@function to validate traffic type
---When traffic is outgoing, src and dest has to be
---lan and wan respectively, when the traffic is incoming
---src and dest should be vice versa
local function setTrafficEndPoints(trafficType)
  local boolean_type =  untaint(trafficType) == "lan" and true or false
    fwrule_defaultObject.src = boolean_type and "lan" or "wan"
    fwrule_defaultObject.dest = boolean_type  and "wan" or "lan"
  return true
end

if post_helper.isFeatureEnabled("firewallTrafficValue", role) then --ti
  fwrule_defaultObject = {src = "wan", dest = "lan"}
end

local fwrule_valid = {
  enabled = validateBoolean,
  target = validateEnumSelect(fwrules_targets),
  src_port = validateOptional(validatePortRange),
  protocol = validateEnumSelect(fwrules_protocols),
  src_ip = validateOptional(validateAnd(validSIPCheck, validateLXC)),
  dest_ip = validateOptional(validateAnd(validDIPCheck, srcdestDuplicateCheck, validateLXC)),
  dest_port = validateOptional(validatePortRange)
}

if post_helper.isFeatureEnabled("firewallDataParams", role) then
  fwrule_valid["traffic"] = setTrafficEndPoints
  fwrule_valid["dscp"] = validateEnumSelect(fwrules_dscp)
end

-- iinet filter
local fwrule_filter
local fwruleDefaultObject = {
  src = "lan",
  dest = "wan"
}

local fwrules_protocols_v6
if not post_helper.isFeatureEnabled("protocollist", role) then
  fwrules_protocols_v6 = {
    { "tcp", T"TCP" },
    { "udp", T"UDP" },
    { "tcpudp", T"TCP/UDP" },
    { "udplite", T"UDPLite" },
    { "icmp", T"ICMPv6" },
    { "esp", T"ESP" },
    { "ah", T"AH" },
    { "sctp", T"SCTP" },
    { "all", T"ALL" }
  }
else
  fwrules_protocols_v6 = protolist.IPv6Protocol
end

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
    attr = { input = { class = "span3", maxlength = "39" }, }
  },
  {
    header = T"icmp-type",
    name = "icmp_type",
    param = "icmp_type.@1.value",
    default = "echo-request",
    type = "select",
    values = icmpTypeList,
    attr = { select = { class = "span2", readonly = "true"}, }
  },
  {
    header = "",
    name = "family",
    param = "family",
    type = "hidden",
    default = "ipv4"
  },
  {
    header = "",
    name = "proto",
    param = "proto.@1.value",
    default = "icmp",
    type = "hidden"
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
    attr = { input = { class = "span3", maxlength = "39" }, }
  },
  {
    header = T"icmp-type",
    name = "icmp_type",
    param = "icmp_type.@1.value",
    default = "echo-request",
    type = "select",
    values = icmpTypeList,
    attr = { select = { class = "span2", readonly = "true"}, }
  },
  {
     header = "",
     name = "family",
     param = "family",
     type = "hidden",
     default = "ipv6"
  },
  {
    header = "",
    name = "proto",
    param = "proto.@1.value",
    default = "icmp",
    type = "hidden"
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
  canEdit = content["fwv4_ping"] == "0" and role ~= "admin",
  canAdd = content["fwv4_ping"] == "0" and role ~= "admin",
  canDelete = content["fwv4_ping"] == "0" and role ~= "admin"
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
  canEdit = content["fwv6_ping"] == "0" and role ~= "admin",
  canAdd = content["fwv6_ping"] == "0" and role ~= "admin",
  canDelete = content["fwv6_ping"] == "0" and role ~= "admin"
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
  name = "WhiteList_"..numList
}

local fwrulev4_ping_valid = {
  enabled = validateBoolean,
  src_ip = validateAnd(validateNonEmpty, removeSpace(post_helper.validateIPv4)),
  icmp_type = validateEnumSelect(icmpTypeList)
}

local fwrulev6_ping_valid = {
  enabled = validateBoolean,
  src_ip = validateAnd(validateNonEmpty, removeSpace(validateIPv6_Subnet)),
  icmp_type = validateEnumSelect(icmpTypeList)
}

local fwrulev4_ping_data, fwrulev4_ping_helpmsg = post_helper.handleTableQuery(fwrulev4_ping_columns, fwrulev4_ping_options, fwrulev4_ping_filter, fwrule_ping_defaultObject, fwrulev4_ping_valid)
local fwrulev6_ping_data, fwrulev6_ping_helpmsg = post_helper.handleTableQuery(fwrulev6_ping_columns, fwrulev6_ping_options, fwrulev6_ping_filter, fwrule_ping_defaultObject, fwrulev6_ping_valid)

-- PING WHITELIST RULES END

local fwrule_data, fwrule_helpmsg
if post_helper.isFeatureEnabled("firewallDataParams", role) then
  fwrule_data, fwrule_helpmsg = post_helper.handleTableQuery(fwrule_columns, fwrule_options, nil, fwrule_defaultObject, fwrule_valid)
else --iinet
  fwrule_data, fwrule_helpmsg = post_helper.handleTableQuery(fwrule_columns, fwrule_options, fwrule_filter, fwruleDefaultObject, fwrule_valid)
end

-- Checking for Modify Use case
local isValidationError = false
if fwrule_helpmsg and next(fwrule_helpmsg) then
 isValidationError = true
end

if ngx.var.request_method == "POST" then
  if ngx.req.get_post_args().tableid == "fwrules" then
   local post_data = ngx.req.get_post_args()
   if isValidationError then
    fwrule_columns[5] = {
	header = T"Src IP/Subnet",
	name = "src_ip",
	param = "src_ip",
	type = "text",
	attr = { input = { class="span2", value = post_data.src_ip, id="src_ipInput" }},
	}
    fwrule_columns[6] = {
	header = T"Src port",
        name = "src_port",
        param = "src_port",
        type = "text",
        attr = { input = { class="span2", value = post_data.src_port, id="src_portInput" }},
        }
    fwrule_columns[7] = {
	header = T"Dst IP/Subnet",
	name = "dest_ip",
	param = "dest_ip",
	type = "text",
	attr = { input = { class="span2", value = post_data.dest_ip, id="dest_ipInput" }},
	}
    fwrule_columns[8] = {
        header = T"Dst port",
        name = "dest_port",
        param = "dest_port",
        type = "text",
        attr = { input = { class="span2", value = post_data.dest_port, id="dest_portInput" }},
	}
   end
  if (post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT") then
    local index = tonumber(post_data.index)
    local text_srcIP = fwrule_data[index][5]
    local text_srcPort = fwrule_data[index][6]
    local text_destIP = fwrule_data[index][7]
    local text_destPort = fwrule_data[index][8]
    local isSameSrcIP = true
    local isSameSrcPort = true
    local isSameDestIP = true
    local isSameDestPort = true

    for _, hostIP in ipairs(new_dest_v4) do
      if text_srcIP == hostIP[1] then
        isSameSrcIP = false
      end
      if text_destIP == hostIP[1] then
        isSameDestIP = false
      end
    end
    for _, hostPort in ipairs(updatedPortlist) do
      if text_srcPort == hostPort[2] then
        isSameSrcPort = false
      end
      if text_destPort == hostPort[2] then
        isSameDestPort = false
      end
    end
    if isSameSrcIP then
	fwrule_columns[5] = {
	header = T"Src IP/Subnet",
        name = "src_ip",
        param = "src_ip",
        type = "text",
        attr = { input = { class="span2", value = post_data.src_ip, id="src_ipInput" }},
        }
    end
    if isSameSrcPort then
	fwrule_columns[6] = {
	header = T"Src port",
        name = "src_port",
        param = "src_port",
        type = "text",
        attr = { input = { class="span2", value = post_data.src_port, id="src_portInput" }},
        }
    end
    if isSameDestIP then
	fwrule_columns[7] = {
	header = T"Dst IP/Subnet",
        name = "dest_ip",
        param = "dest_ip",
        type = "text",
        attr = { input = { class="span2", value = post_data.dest_ip, id="dest_ipInput" }},
        }
    end
    if isSameDestPort then
	fwrule_columns[8] = {
	header = T"Dst port",
        name = "dest_port",
        param = "dest_port",
        type = "text",
        attr = { input = { class="span2", value = post_data.dest_port, id="dest_portInput" }},
        }
    end

  end
 end
end
-- END


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
  { -- Not needed for ti
    header = T"TrafficType",
    name = "traffic_v6",
    param = "src",
    default = "INCOMING",
    type = "select",
    values = traffic_policy,
    attr = { select = { class = "span1", style = "width: 100px" } }
  },
  {
    header = T"Action",
    name = "target_v6",
    param = "target",
    default = "DROP",
    type = "select",
    values = fwrules_targets,
    attr = { select = { class = "span1", style = "width: 100px" } }
  },
  {
    header = T"Protocol",
    name = "protocol_v6",
    param = "proto",
    default = "tcp",
    type = "select",
    values = fwrules_protocols_v6,
    attr = { select = { class = "span1", style = "width: 100px" } }
  },
  {
    header = T"Src IP/Subnet",
    name = "src_ip_v6",
    param = "src_ip",
    type = "select",
    values = new_dest_v6,
    attr = { select = { class = "span2"}}
  },
  {
    header = T"Src port",
    name = "src_port_v6",
    param = "src_port",
    values = updatedPortlist,
    type = "select",
    attr = { select = { class = "span1"}}
  },
  {
    header = T"Dst IP/Subnet",
    name = "dest_ip_v6",
    param = "dest_ip",
    type = "select",
    values = new_dest_v6,
    attr = { select = { class = "span2"}}
  },
  {
    header = T"Dst port",
    name = "dest_port_v6",
    param = "dest_port",
    values = updatedPortlist,
    type = "select",
    attr = { select = { class = "span1"}}
  },
  {
    header = T"DSCP",
    name = "dscp_v6",
    param = "extra",
    default = "",
    type = "select",
    values = fwrules_dscp,
    attr = { select = { class = "span1", style = "width: 100px" } }
  },
}

local fwrule_v6_options = {
  tableid = "fwrules_v6",
  basepath = "rpc.network.firewall.userrule_v6.@.",
  createMsg = T"Add new IPv6 firewall rule",
  valid = rulesDuplicateCheck

}

local fwrule_v6_valid = {
  enabled_v6 = validateBoolean,
  target_v6 = validateEnumSelect(fwrules_targets),
  src_port_v6 = validateOptional(validatePortRange),
  protocol_v6 = validateEnumSelect(fwrules_protocols_v6),
  src_ip_v6 = validateOptional(post_helper.validateIPv6),
  dest_ip_v6 = validateAnd(post_helper.validateIPv6, srcdestDuplicateCheck),
  dest_port_v6 = validateOptional(validatePortRange)
}

if post_helper.isFeatureEnabled("firewallDataParams", role) then
  fwrule_v6_options["sorted"] = fwrule_sort
  fwrule_v6_valid["traffic_v6"] = setTrafficEndPoints
  fwrule_v6_valid["dscp_v6"] = validateEnumSelect(fwrules_dscp)
end

local fwrule_v6_data, fwrule_v6_helpmsg
--Generic Part
if post_helper.isFeatureEnabled("firewallDataParams", role) then
  fwrule_v6_data, fwrule_v6_helpmsg = post_helper.handleTableQuery(fwrule_v6_columns, fwrule_v6_options, nil, fwrule_defaultObject, fwrule_v6_valid)
else --iinet
  fwrule_v6_data, fwrule_v6_helpmsg = post_helper.handleTableQuery(fwrule_v6_columns, fwrule_v6_options, fwrule_filter, fwrule_defaultObject, fwrule_v6_valid)
end

--Check EDIT Functionality for _v6
local isValidationError_v6 = false
if fwrule_v6_helpmsg and next(fwrule_v6_helpmsg) then
 isValidationError_v6 = true
end

if ngx.var.request_method == "POST" then
  if ngx.req.get_post_args().tableid == "fwrules_v6" then
   local post_data = ngx.req.get_post_args()
   if isValidationError_v6 then
    fwrule_v6_columns[5] = {
        header = T"Src IP/Subnet",
        name = "src_ip_v6",
        param = "src_ip",
        type = "text",
        attr = { input = { class="span2", value = post_data.src_ip_v6, id="src_ip_v6Input" }},
        }
    fwrule_v6_columns[6] = {
	header = T"Src port",
        name = "src_port_v6",
        param = "src_port",
        type = "text",
        attr = { input = { class="span2", value = post_data.src_port_v6, id="src_port_v6Input" }},
        }
    fwrule_v6_columns[7] = {
        header = T"Dst IP/Subnet",
        name = "dest_ip_v6",
        param = "dest_ip",
        type = "text",
        attr = { input = { class="span2", value = post_data.dest_ip_v6, id="dest_ip_v6Input" }},
        }
    fwrule_v6_columns[8] = {
        header = T"Dst port",
        name = "dest_port_v6",
        param = "dest_port",
        type = "text",
        attr = { input = { class="span2", value = post_data.dest_port_v6, id="dest_port_v6Input" }},
      }
   end
  if (post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT") then
    local index = tonumber(post_data.index)
    local text_srcIP_v6 = fwrule_v6_data[index][5]
    local text_srcPort_v6 = fwrule_v6_data[index][6]
    local text_destIP_v6 = fwrule_v6_data[index][7]
    local text_destPort_v6 = fwrule_v6_data[index][8]
    local isSameSrcIP_v6 = true
    local isSameSrcPort_v6 = true
    local isSameDestIP_v6 = true
    local isSameDestPort_v6 = true

    for _, hostIP_v6 in ipairs(new_dest_v6) do
      if text_srcIP_v6 == hostIP_v6[1] then
        isSameSrcIP_v6 = false
      end
      if text_destIP_v6 == hostIP_v6[1] then
        isSameDestIP_v6 = false
      end
    end
    for _, hostPort_v6 in ipairs(updatedPortlist) do
      if text_srcPort_v6 == hostPort_v6[2] then
        isSameSrcPort_v6 = false
      end
      if text_destPort_v6 == hostPort_v6[2] then
        isSameDestPort_v6 = false
      end
    end
    if isSameSrcIP_v6 then
	fwrule_v6_columns[5] = {
	header = T"Src IP/Subnet",
        name = "src_ip_v6",
        param = "src_ip",
        type = "text",
        attr = { input = { class="span2", value = post_data.src_ip_v6, id="src_ip_v6Input" }},
        }
    end
    if isSameSrcPort_v6 then
	fwrule_v6_columns[6] = {
	header = T"Src port",
        name = "src_port_v6",
        param = "src_port",
        type = "text",
        attr = { input = { class="span2", value = post_data.src_port_v6, id="src_port_v6Input" }},
        }
    end
    if isSameDestIP_v6 then
	fwrule_v6_columns[7] = {
	header = T"Dst IP/Subnet",
        name = "dest_ip_v6",
        param = "dest_ip",
        type = "text",
        attr = { input = { class="span2", value = post_data.dest_ip_v6, id="dest_ip_v6Input" }},
        }
    end
    if isSameDestPort_v6 then
	fwrule_v6_columns[8] = {
	header = T"Dst port",
        name = "dest_port_v6",
        param = "dest_port",
        type = "text",
        attr = { input = { class="span2", value = post_data.dest_port_v6, id="dest_port_v6Input" }},
        }
    end
  end
 end
end
--END

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
');  
  local currentFirewallMode = proxy.get("rpc.network.firewall.mode")[1].value
  local hasAdvanced = false
  if currentFirewallMode == "user" and post_helper.isFeatureEnabled("firewallAdvancedView", role) then
    hasAdvanced = true
  end
  ngx.print(ui_helper.createHeader(T"Firewall", hasAdvanced, true))
  ngx.print('\
\
<div class = "modal-body update">\
  <form class = "form-horizontal" method = "post" action = "modals/firewall-modal.lp">\
    ');  
      ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"Firewall level" ); ngx.print('</legend>\
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
        if post_helper.isFeatureEnabled("firewallModeDropdown", role) then --Generic
          ngx.print(ui_helper.createInputSelect(T"Level", "fw_level", fw_levels, content["fw_level"], fwlevel_attr))
        else -- ti, iinet
          ngx.print(ui_helper.createSliderSelect(T"Level", "fw_level", fw_levels, content["fw_level"], fwlevel_attr))
        end
        ngx.print(
          ui_helper.createAlertBlock(T"In <strong>low mode</strong>, firewall allows all outbound connections and rejects unknown incoming connections but acknowledges presence of the gateway.", lax_attr),
          ui_helper.createAlertBlock(T"In <strong>medium mode</strong>, firewall allows all outbound connections and silently drops unknown incoming connections.", normal_attr))
          if post_helper.getVariantValue(variantHelper, "levelMessage") then
            ngx.print(ui_helper.createAlertBlock(T"In <strong>high mode</strong>, firewall allows outgoing connections to HTTP, HTTPS, SMTP, POP3, IMAP, SSH services and silently drops unknown incoming connections. This may impact on web services like Internet Speed Test.", high_attr))
          else
            ngx.print(ui_helper.createAlertBlock(T"In <strong>high mode</strong>, firewall allows outgoing connections to HTTP, HTTPS, SMTP, POP3, IMAP, SSH services and silently drops unknown incoming connections.", high_attr))
          end
          ngx.print(ui_helper.createAlertBlock(T"In <strong>user mode</strong>, individual firewall rules may be configured as well as the default behavior.", user_attr)
        )
        ngx.print('\
    </fieldset>\
\
    <fieldset>\
      <legend>');  ngx.print( T"Firewall default behavior" ); ngx.print('</legend>\
      ');  
      -- To monitor the ping enable switch
      local switch_class_enable = {
        input = {
          class = "monitor-changes"
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
      if post_helper.isFeatureEnabled("internetPing", role) then --generic, ti
        ngx.print(ui_helper.createSwitch(T"Answer All IPv4 Internet pings", "fwv4_ping", content["fwv4_ping"], switch_class_enable))
        ngx.print(ui_helper.createAlertBlock(T"Answer only these selected Internet IPv4 pings", pingrespv4_alert_attr))
        ngx.print(ui_helper.createTable(fwrulev4_ping_columns, fwrulev4_ping_data, fwrulev4_ping_options, pingrespv4_table_attr, fwrulev4_ping_helpmsg))
        if post_helper.isFeatureEnabled("ipv6Firewall", role) then --ti
	  ngx.print(ui_helper.createSwitch(T"IPv6 Firewall", "fw_ipv6", content["fw_ipv6"]))
        end
        ngx.print(ui_helper.createSwitch(T"Answer All IPv6 Internet pings", "fwv6_ping", content["fwv6_ping"], switch_class_enable))
        ngx.print(ui_helper.createAlertBlock(T"Answer only these selected Internet IPv6 pings", pingrespv6_alert_attr))
        ngx.print(ui_helper.createTable(fwrulev6_ping_columns, fwrulev6_ping_data, fwrulev6_ping_options, pingrespv6_table_attr, fwrulev6_ping_helpmsg))
      else --iinet
        ngx.print(ui_helper.createSwitch(T"Answer Internet ping", "fw_ping", content["fw_ping"]))
      end
        ngx.print('\
    </fieldset>\
\
    ');  if post_helper.isFeatureEnabled("firewallAdvancedView", role) then   ngx.print('\
      <fieldset class = "advanced hide">\
    ');  else   ngx.print('\
      <fieldset>\
    ');  end   ngx.print('\
    <legend></legend>\
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
      ngx.print(
        ui_helper.createInputSelect(T"Outgoing default policy", "fw_outgoing_policy", outgoingpolicy, content["fw_outgoing_policy"], outgoing_attr),
        ui_helper.createAlertBlock(T"The <strong>outgoing policy</strong> defines what is done with packets coming from the LAN devices toward the internet. Setting it to REJECT or DROP will forbid any internet traffic from the LAN unless explicitly allowed by a firewall rule.", info_attr),
        ui_helper.createInputSelect(T"Incoming default policy", "fw_incoming_policy", incomingpolicy, content["fw_incoming_policy"], outgoing_attr),
        ui_helper.createAlertBlock(T"The <strong>incoming policy</strong> defines what is done with packets destined to the gateway. They can be either REJECTED (the gateway will notify the sender they were rejected) or DROPPED (the gateway will silently discard those packets).", info_attr)
      )
      ngx.print('\
    </fieldset>\
\
    <fieldset class = "monitor-fw_level monitor-user ');  ngx.print( fwallmsg_visible_status["user"]); ngx.print('">\
      ');  local advanced = {
           group = {
             class = "advanced hide",
           }
         }
         local advanced_attr = {
           alert = {
             class = "advanced hide",
           }
         }
        ngx.print('\
      ');  if post_helper.isFeatureEnabled("firewallAdvancedView", role) then   ngx.print('\
        <legend class = "advanced hide">');  ngx.print( T"IPv4 Firewall Rules" ); ngx.print('</legend>\
        ');  ngx.print(ui_helper.createAlertBlock(T"<strong>Addition of wildcard rules might create race conditions</strong>, ensure before adding wild card rules", advanced_attr))   ngx.print('\
        ');  ngx.print(ui_helper.createTable(fwrule_columns, fwrule_data, fwrule_options, advanced, fwrule_helpmsg))   ngx.print('\
      ');  else   ngx.print('\
        <legend>');  ngx.print( T"IPv4 Firewall Rules" ); ngx.print('</legend>\
        ');  ngx.print(ui_helper.createTable(fwrule_columns, fwrule_data, fwrule_options, nil, fwrule_helpmsg))   ngx.print('\
      ');  end   ngx.print('\
    </fieldset>\
\
    <fieldset class = "monitor-fw_level monitor-user ');  ngx.print( fwallmsg_visible_status["user"]); ngx.print('">\
      ');  local advanced = {
           group = {
             class = "advanced hide",
           }
         }
         local advanced_attr = {
           alert = {
             class = "advanced hide",
           }
         }
        ngx.print('\
      ');  if post_helper.isFeatureEnabled("firewallAdvancedView", role) then   ngx.print('\
        <legend class = "advanced hide">');  ngx.print( T"IPv6 Firewall Rules" ); ngx.print('</legend>\
        ');  ngx.print(ui_helper.createAlertBlock(T"<strong>Addition of wildcard rules might create race conditions</strong>, ensure before adding wild card rules", advanced_attr))   ngx.print('\
        ');  ngx.print(ui_helper.createTable(fwrule_v6_columns, fwrule_v6_data, fwrule_v6_options, advanced, fwrule_v6_helpmsg))   ngx.print('\
      ');  else   ngx.print('\
        <legend>');  ngx.print( T"IPv6 Firewall Rules" ); ngx.print('</legend>\
        ');  ngx.print(ui_helper.createTable(fwrule_v6_columns, fwrule_v6_data, fwrule_v6_options, nil, fwrule_v6_helpmsg))   ngx.print('\
      ');  end   ngx.print('\
    </fieldset>\
\
    ');  if post_helper.isFeatureEnabled("sipAlg", role) then   ngx.print('\
      ');  if #alg_sip_paths > 0 then   ngx.print('\
        <fieldset>\
          <legend>');  ngx.print( T"ALG Configuration" ); ngx.print('</legend>\
          ');  ngx.print( ui_helper.createSwitch(T"ALG SIP", "fw_alg_sip_1", content["fw_alg_sip_1"])); ngx.print('\
          ');  
          local alert_sip = {
            alert = {
              class = "alert hide",
              id = "alert-sip-alg"
            }
          }
            ngx.print('\
          ');  ngx.print(ui_helper.createAlertBlock(T"If you have a SIP device connected to the modem, you will need to restart that device for the change in SIP ALG to take effect.", alert_sip))   ngx.print('\
        </fieldset>\
      ');  end   ngx.print('\
    ');  end   ngx.print('\
  </form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
<script>\
var sipAlg = "');  ngx.print(sipAlg); ngx.print('";\
var trafficTypeValue = ');  ngx.print(trafficTypeValue); ngx.print(';\
var dscpValue = ');  ngx.print(dscpValue); ngx.print(';\
var protocollist = ');  ngx.print(protocollist); ngx.print(';\
if(protocollist == "false") {\
  var portLessProtocol = {};\
  ');  for _, protolistValue in ipairs(protolist.portless_proto) do   ngx.print('\
    portLessProtocol["');  ngx.print( protolistValue[1] ); ngx.print('"] = true;\
  ');  end  ngx.print('\
}\
</script>\
<script src="/js/firewall.js"></script>\
'); 