--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ngx = ngx
local lp = require("web.lp")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local portslist = require("portslist_helper")
local wanservices = require("webui_core.wanservices")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac, hosts_ac_v6 = uinetwork.getAutocompleteHostsList()
local pairs, string = pairs, string
local table, ipairs, tonumber, format, match = table, ipairs, tonumber, string.format, string.match
local session = ngx.ctx.session
local role = session:getrole()
local wanIntf = post_helper.getActiveInterface()
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "WANServices", "PortMapping")
local variantHelperSettings = post_helper.getVariant(variant_helper, "WANServices", "Settings")
local showIPv6DMZ = post_helper.getVariantValue(variantHelperSettings, "showIPv6DMZ")

local new_dest_v4, new_dest_v6 = {}, {}
for k,v in pairs(hosts_ac) do
  new_dest_v4[#new_dest_v4+1] = {v,k}
end

for k,v in pairs(hosts_ac_v6) do
  new_dest_v6[#new_dest_v6+1] = {v,k}
end

local igd_select = {
  { "igdv1", T'1'},
  { "igdv2", T'2'}
}
-- Source IP is not supported in TI
local sourceIPValue = post_helper.isFeatureEnabled("wanServicesPortMapSourceIP", role) and 0 or 1

-- Retrieve GW IP + netmask for use by validation function
local ipdetails = {
  gw = "uci.network.interface.@lan.ipaddr",
  netmask = "uci.network.interface.@lan.netmask"
}
content_helper.getExactContent(ipdetails)

-- UPnP switches Only one handleQuery in a page
local qry_params = {
  upnp_status = "uci.upnpd.config.enable_upnp",
  upnp_natpmp = "uci.upnpd.config.enable_natpmp",
  upnp_secure_mode = "uci.upnpd.config.secure_mode",
  upnp_igd_version = "uci.upnpd.config.datamodel_version"
}

if post_helper.getVariantValue(variantHelper, "DMZ") then
qry_params.DMZ_enable = "rpc.network.firewall.dmz.enable"
qry_params.DMZ_destinationip = "rpc.network.firewall.dmz.redirect.dest_ip"
end

-- Shortcuts to validation helpers to make lines shorter
local validateEnum = post_helper.getValidateInEnumSelect
local validateBoolean = post_helper.validateBoolean
local validatePortRange = post_helper.validateStringIsPortRange
local validateDeviceIPv4 = post_helper.getValidateStringIsDeviceIPv4
local validateStringIPv6 = post_helper.validateStringIsIP(6)
local validateDeviceIP = validateDeviceIPv4(ipdetails.gw, ipdetails.netmask)
local andValidation = post_helper.getAndValidation
local orValidation = post_helper.getOrValidation
local validateQTN = post_helper.validateQTN
local optionalValidation = post_helper.getOptionalValidation
local validateIPv4 = post_helper.validateStringIsIP(4)
local isPortAndProtoReserved, reserved_ports = wanservices.isPortAndProtoReserved()
local validateLXC = post_helper.validateLXC
local validateDMZ = post_helper.validateDMZ

local qry_valid = {
  upnp_status = validateBoolean,
  upnp_natpmp = validateBoolean,
  upnp_secure_mode = validateBoolean,
  upnp_igd_version = validateEnum(igd_select)
}

if post_helper.getVariantValue(variantHelper, "DMZ") then
qry_valid.DMZ_enable = validateBoolean
qry_valid.DMZ_destinationip = validateDMZ
end

local del_pfw_index = nil
local del_pfw_data = {}

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)

if not qry_data.upnp_igd_version or qry_data.upnp_igd_version == "" then
  qry_data.upnp_igd_version = "igdv2"
end

if ngx.var.request_method == "POST" then
  local content = ngx.req.get_post_args()
  if content.action == "TABLE-DELETE" and content.tableid == "portforwarding" then
    del_pfw_index = tonumber(content.index)
  end
end

local ipv6wan2lan_path = "uci.firewall.forwarding.@ipv6wan2lan."

local function get_ipv6_wan2lan()
  if proxy.get(ipv6wan2lan_path) ~= nil then
    return "1"
  else
    return "0"
  end
end

local function disable_ipv6_wan2lan()
  if proxy.del(ipv6wan2lan_path) then
    proxy.apply()
  end
end

local function enable_ipv6_wan2lan()
  if  proxy.add("uci.firewall.forwarding.", "ipv6wan2lan") then
    local ipv6_wan2lan_values = {
      [ipv6wan2lan_path.."src"] ="wan",
      [ipv6wan2lan_path.."dest"] = "lan",
      [ipv6wan2lan_path.."family"] = "ipv6",
    }
    if proxy.set(ipv6_wan2lan_values) then
      proxy.apply()
    end
  end
end

local action
if ngx.var.request_method == "POST" then
  local content = ngx.req.get_post_args()
  if content.action == "SAVE" and post_helper.isFeatureEnabled("ipv6wan2lan") then
    if content.ipv6wan2lan ~= get_ipv6_wan2lan() then
      if content.ipv6wan2lan == "1" then
        enable_ipv6_wan2lan()
      else
        disable_ipv6_wan2lan()
      end
    end
  end
  if content.action == "TABLE-DELETE" and content.tableid == "portforwarding" then
    del_pfw_index = tonumber(content.index)
  end
end

-- In UCI
--config 'userredirect'
--        option 'enabled'  '1'
--        option 'name' 'ssh'
--        option 'src' 'wan'
--        option 'proto' 'tcp'
--        option 'src_dport' '5555'
--        option 'dest_ip' '192.168.1.100'
--        option 'dest_mac' '9c:97:26:c5:9b:28'
--        option 'dest_port' '22'
--        option 'target' 'DNAT'
--        option 'dest' 'lan'

-- In Transformer
-- rpc.network.firewall.portforward.{i}.enabled
-- rpc.network.firewall.portforward.{i}.name
-- rpc.network.firewall.portforward.{i}.src
-- rpc.network.firewall.portforward.{i}.src_dport
-- rpc.network.firewall.portforward.{i}.dest_ip
-- rpc.network.firewall.portforward.{i}.dest_mac
-- rpc.network.firewall.portforward.{i}.dest_port
-- rpc.network.firewall.portforward.{i}.target
-- rpc.network.firewall.portforward.{i}.dest
-- rpc.network.firewall.portforward.{i}.proto.@1.value

-- Templates for pre-defined rules
local function table_removekey(portRemoveList, key)
  local element = portRemoveList[key]
  portRemoveList[key] = nil
  return element
end

-- Validation for PortLimit(Different lengths of WAN and LAN should not be accepted)
local function validPortLimit(ports)
  for _, v in ipairs(ports) do
    local wanPortStart = tonumber(v.startPort)
    local wanPortEnd = tonumber(v.endPort)
    local lanPortStart = tonumber(v.lanPortStart)
    local lanPortEnd = tonumber(v.lanPortEnd)
    if not (lanPortEnd - lanPortStart == wanPortEnd - wanPortStart) then
      return nil, { lanport = T"Port Ranges must be equal length" }
    end
  end
  return true
end

--Remove the ports configured in system.wan-service in allowed_portlist
local allowed_portlist = portslist
for wanPort, _ in pairs(reserved_ports) do
  for i, j in pairs(allowed_portlist) do
    if wanPort and (tonumber(wanPort) == tonumber(j)) then
      table_removekey(allowed_portlist,i)
    end
  end
end

local knownapps = require("pfwd_helper")

local updatedPortlist = {}
for service, port in pairs(allowed_portlist) do
  updatedPortlist[#updatedPortlist+1] = {port, service}
end

updatedPortlist[#updatedPortlist + 1] = {"custom", T"Custom"}
new_dest_v4[#new_dest_v4 + 1] = {"custom", T"Custom"}
new_dest_v6[#new_dest_v6 + 1] = {"custom", T"Custom"}

local pfw_helper_map = {}

pfw_helper_map["FTP server"] = {pfw = "FTP server", helper = "ftp", wanport = "21"}
pfw_helper_map["TFTP server"] = {pfw = "TFTP server", helper = "tftp", wanport = "69"}
pfw_helper_map["PPTP"] = {pfw = "PPTP", helper = "pptp", wanport = "1723"}


local portrange_pattern = "^(%d+)%:(%d+)$"
local function compare_startport(a,b)
  return a.startPort < b.startPort
end

-- Firewall forwarding rules
local pfw_columns = {
  {
    header = "",
    name = "enabled",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" } }
  },
  {
    header = T"Name",
    name = "name",
    param = "name",
    type = "text",
    unique = true,
    attr = { input = { class="span2" } },
  },
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto.@1.value",
    default = "tcp",
    type = "select",
    values = {
      { "tcp", "TCP"},
      { "udp", "UDP"},
      { "tcpudp", "TCP/UDP"}
    },
    attr = { select = { class="span2" } },
  },
  {
    header = T"WAN port",
    name = "wanport",
    param = "src_dport",
    type = "select",
    values = updatedPortlist,
    attr = { select = { class="span1"}},
  },
  {
    header = T"LAN port",
    name = "lanport",
    param = "dest_port",
    type = "select",
    values = updatedPortlist,
    attr = { select = { class="span1"} },
  },
  {
    header = T"Source IP",
    name = "sourceip",
    param = "src_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15" , id = "sourceip"} },
  },
  {
    header = T"Destination IP",
    name = "destinationip",
    param = "dest_ip",
    type = "select",
    values = new_dest_v4,
    attr = { select = { class="span2"}},
  },
  {
    header = T"Destination MAC",
    name = "destinationmac",
    param = "dest_mac",
    type = "text",
    readonly = true,
    attr = {  },
  },
}


local function globalValid(data)
  local tcp = {}
  local udp = {}
  local p1, p2, p3, p4
  local err, msg

    if del_pfw_index ~= nil then
      del_pfw_data = content_helper.loadTableData("rpc.network.firewall.portforward.", pfw_columns, nil, "name")
    end

    for columnIndex, columnValue in ipairs(data) do
      if columnValue[3] and columnValue[4] then
        local wanChunks = { columnValue[4]:match(portrange_pattern) }
        if #wanChunks == 2 then
          p1 = tonumber(wanChunks[1])
          p2 = tonumber(wanChunks[2])
        else
          p1 = tonumber(columnValue[4])
          p2 = p1
        end

        local lanChunks = { columnValue[5]:match(portrange_pattern) }
        if #lanChunks == 2 then
          p3 = tonumber(lanChunks[1])
          p4 = tonumber(lanChunks[2])
        else
          p3 = tonumber(columnValue[5])
          p4 = p3
        end

        local proto = columnValue[3]
        local destIP_ipv4 = columnValue[7]
        if proto == "tcp" or proto == "tcpudp" then
          tcp[#tcp + 1] = { startPort = p1, endPort = p2, lanPortStart = p3, lanPortEnd = p4, index = columnIndex, portProtocol = proto, dest_ip_ipv4 = destIP_ipv4 }
        end
        if proto == "udp" or proto == "tcpudp" then
          udp[#udp+1] = { startPort = p1, endPort = p2, lanPortStart = p3, lanPortEnd = p4, index = columnIndex, portProtocol = proto, dest_ip_ipv4 = destIP_ipv4 }
        end
      end
    end

    table.sort(tcp, compare_startport)
    table.sort(udp, compare_startport)

    err, msg = validPortLimit(tcp)
    if not err then
      return err, msg
    end
    err, msg = validPortLimit(udp)
    if not err then
      return err, msg
    end

    err, msg = post_helper.validPorts(tcp)
    if not err then
      return err, msg
    end
    err, msg = post_helper.validPorts(udp)
    return err, msg
end

local function getValidateName(value)
  if #value == 0 or #value > 63 then
    return nil, T"A name must be between 1 and 63 characters"
  end
  -- "DMZ rule" is the name reserved for DMZ portmap rule
  if value == "DMZ rule" then
    return nil, T"Reserved name cannot be given as rule name"
  end
  if match(value, "[^%w%-%s%æ%ø%å%Æ%Ø%Å]") then
    return nil, T"A name must contain only alphanumeric characters and dash"
  end
  return true
end

-- check if protocols duplicate
local function isProtocolDuplicate(protocol_1, protocol_2)
  local protoMap  = {
    tcp    = {"tcp"},
    udp    = {"udp"},
    tcpudp = {"tcp", "udp"},
    icmpv6 = {"icmpv6"},
    all    = {"all"},
  }
  local port_1_val = protoMap[string.untaint(protocol_1)]
  local port_2_val = protoMap[string.untaint(protocol_2)]
  for _, proto_1 in ipairs(port_1_val) do
    for _, proto_2 in ipairs(port_2_val) do
      if proto_1 == proto_2 then
        -- return true since protocols duplicate
        return true
      end
    end
  end
  return false
end

local DMZ_rule_present = "0"
local DMZ_destinationip_ipv6 = ""
if showIPv6DMZ then
  local pinholerules = content_helper.convertResultToObject("rpc.network.firewall.pinholerule.", proxy.get("rpc.network.firewall.pinholerule."))
  for _, v in ipairs(pinholerules) do
    if (v.name == "DMZ IPv6 Rule" and v.enabled =="1") then
      DMZ_rule_present = "1"
      DMZ_destinationip_ipv6 = v.dest_ip
    end
  end
end

-- check if ports overlap (or equal)
local function isPortsOverlap(port_1, port_2)
  local port_1_splitted = { port_1:match(portrange_pattern) }
  local port_2_splitted = { port_2:match(portrange_pattern) }
  -- split range
  local port_1_start = #port_1_splitted == 2 and tonumber(port_1_splitted[1]) or tonumber(port_1)
  local port_1_end   = #port_1_splitted == 2 and tonumber(port_1_splitted[2]) or port_1_start
  local port_2_start = #port_2_splitted == 2 and tonumber(port_2_splitted[1]) or tonumber(port_2)
  local port_2_end   = #port_2_splitted == 2 and tonumber(port_2_splitted[2]) or port_2_start
  -- return true if overlap
  return math.max(port_1_start, port_2_start) <= math.min(port_1_end, port_2_end)
end

-- check if ipv6 destinations same
local function isIpv6DestinationsSame(destination_1, destination_2)
  for dest_1 in destination_1:gmatch("([^%s]+)") do
    for dest_2 in destination_2:gmatch("([^%s]+)") do
      if dest_1 == dest_2 then
        return true
      end
    end
  end
  return false
end

-- check if ipv6 forward rules duplicate
local function rulesDuplicateCheck(object)
  if showIPv6DMZ and object and object[#object] and isIpv6DestinationsSame(object[#object][6], DMZ_destinationip_ipv6) then
    return nil, {dest_ip_v6 = T"DMZ is already enabled for this device, Disable DMZ to add here"}
  end
  for row = 1, #object do
    for n = row+1, #object do
      if post_helper.getVariantValue(variantHelper, "IPv6Port") then
        if object[n][3] ~= "icmpv6" and object[n][3] ~= "all" and object[row][3] ~= "icmpv6" and object[row][3] ~= "all" then
          if isIpv6DestinationsSame(object[row][6], object[n][6]) and
            isPortsOverlap(object[row][4], object[n][4]) and
            isProtocolDuplicate(object[row][3], object[n][3]) then
            return nil, {wanport = T"duplicate value"}
          end
        else
          if isIpv6DestinationsSame(object[row][6], object[n][6]) and object[row][3] == object[n][3]  then
            return nil, {protocol = T"duplicate value"}
          end
        end
      else
        if isIpv6DestinationsSame(object[row][6], object[n][6]) and
          isPortsOverlap(object[row][4], object[n][4]) and
          isProtocolDuplicate(object[row][3], object[n][3]) then
          return nil, {wanport = T"duplicate value"}
        end
      end
    end
  end
  return true
end

local protocolList = {
  { "tcp", "TCP"},
  { "udp", "UDP"},
  { "tcpudp", "TCP+UDP"}
}

local function sourceIPCheck(ipaddr)
  if ipdetails.gw == ipaddr then
    return nil, T"Cannot use GatewayIP address range"
  end
  local success, _ = post_helper.isNetworkAddress(ipaddr, ipdetails.netmask)
    if success then
      return nil, T"Cannot use the network address"
    end
    return true
end

local function validateNotSameSourceAndDestinationIP(value, object, key)
  local type = ""
  if object.tableid == "portforwarding" then
    type = "ipv4"
  elseif object.tableid == "fwrules_v6" then
    type = "ipv6"
  end
  return post_helper.validateNotSameSourceAndDestinationIP(value, object, key, type)
end

local function sourceIPv4Validation(value, object, key)
  local success, errmsg = post_helper.validateIPAndSubnet(4)(value, object, key)
  if success then
    local ipAddress, _ = match(string.untaint(value), "^([^/]+)/?(%d*)$")
    success, errmsg = validateIPv4(ipAddress, object, key)
    if not success then
      return nil, errmsg
    end
    success, errmsg = validateQTN(ipAddress, object, key)
    if not success then
      return nil, errmsg
    end
    success, errmsg = validateLXC(ipAddress, object, key)
    if not success then
      return nil, errmsg
    end
    success, errmsg = post_helper.reservedIPValidation(ipAddress, object, key)
    if not success then
      return nil, errmsg
    end
    success, errmsg = post_helper.advancedIPValidation(ipAddress, object, key)
    if not success then
      return nil, errmsg
    end
    success, errmsg = sourceIPCheck(ipAddress, object, key)
    if not success then
      return nil, errmsg
    end
  elseif value == "" then
    return true
  else
    return nil, errmsg
  end
  return true
end

local pfw_valid = {
  enabled = validateBoolean,
  name = getValidateName,
  lanport = validatePortRange,
  wanport = andValidation(validatePortRange,isPortAndProtoReserved),
  sourceip = sourceIPv4Validation,
  destinationip = andValidation(validateDeviceIP,validateQTN, validateLXC, post_helper.reservedIPValidation, validateNotSameSourceAndDestinationIP),
  protocol = validateEnum(protocolList)
}

-- ip handleTableQuery parameter filter callback to only show ipv4 port forwardings ...
-- and only user created rules
-- return true if entry should be displayed
local function pfw_filter(data)
  -- check handled only to display the destination IPv4 address in destination field of portmap rule
  data.dest_ip = data.dest_ip:match("(%d+%.%d+%.%d+%.%d+)") and data.dest_ip:match("(%d+%.%d+%.%d+%.%d+)") .. " " or ""
  if (data.target == "DNAT" and
    data.src == wanIntf and
    data.dest == "lan" and
    data.family == "ipv4" and data.name ~= "DMZ rule" and data.src_dport ~= "") then
    return true
  end

  return false
end

-- Warning, this uses transformer paths. So use correct naming
local pfw_defaultObject = {
  src = wanIntf ,
  dest = "lan",
  family = "ipv4",
  target = "DNAT"
}

local function set_helper_port(helper, port)
  local path = "uci.firewall_helpers.helper."
  local data = proxy.get(path)

  if data == nil then
    return
  end

  for _,v in ipairs(data) do
    if v.param == "helper" and v.value == helper then
      proxy.set(v.path .. "dest_port", port)
      return
    end
  end

end

local function get_firewall_helper(userredir_name)
  for _, tmp in pairs(pfw_helper_map) do
    if userredir_name == tmp.pfw then
      return tmp
    end
  end

  return nil
end

local function get_firewall_helper_name(userredir_name)
  local tmp = get_firewall_helper(userredir_name)

  if tmp ~= nil then
    return tmp["helper"]
  else
    return nil
  end
end

local function update_firewall_helper(index, content)
  if index == nil then
    return
  end

  local helper = get_firewall_helper_name(content.name)

  -- the corresponding helper in firewall should be updated also
  if helper ~= nil then
    if content.enabled == "1" then
      set_helper_port(helper, string.untaint(content.wanport))
    else
      set_helper_port(helper, pfw_helper_map[string.untaint(content.name)].wanport)
    end
  end
end

local function onDelete(index)
  if del_pfw_index == nil then
    return
  end

  local helper = get_firewall_helper(del_pfw_data[del_pfw_index][2])
  del_pfw_index = nil

  if helper ~= nil and helper["wanport"] ~= nil then
    set_helper_port(helper.helper, helper.wanport)
  end
end

local pfw_options = {
  tableid = "portforwarding",
  basepath = "rpc.network.firewall.portforward.",
  createMsg = T"Add new IPv4 port mapping",
  newList = knownapps,
  valid = globalValid,
  sorted = "name",
  onModify = update_firewall_helper,
  onAdd = update_firewall_helper,
  onDelete = onDelete
}

local pfw_data, pfw_helpmsg = post_helper.handleTableQuery(pfw_columns, pfw_options, pfw_filter, pfw_defaultObject, pfw_valid)

local isValidationError = false
if pfw_helpmsg and next(pfw_helpmsg) then
 isValidationError = true
end

if ngx.var.request_method == "POST" then
  local post_data = ngx.req.get_post_args()
  if post_data.tableid == "portforwarding" then
  if isValidationError then
    pfw_columns[4] = {
        header = T"WAN port",
        name = "wanport",
        param = "src_dport",
        type = "text",
        attr = { input = { class="span1", value = post_data.wanport, id="wanportInput" }},
        }
    pfw_columns[5] = {
        header = T"LAN port",
        name = "lanport",
        param = "dest_port",
        type = "text",
        attr = { input = { class="span1", value =  post_data.lanport, id="lanportInput" }},
        }
    pfw_columns[7] = {
        header = T"Destination IP",
        name = "destinationip",
        param = "dest_ip",
        type = "text",
        attr = { input = { class="span2", value = post_data.destinationip, id="destinationipInput" }},
      }
  end
  if (post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT") then
    local index = tonumber(post_data.index)
    local text_destIP = pfw_data[index][7]
    local text_WANPort = pfw_data[index][4]
    local text_LANPort = pfw_data[index][5]
    local isSameDestIP = true
    local isSameWANPort = true
    local isSameLANPort = true
    text_destIP = text_destIP:match("([^%s]+)") or ""
    for _, hostDestIP in ipairs(new_dest_v4) do
     if text_destIP == hostDestIP[1] or text_destIP == "unknown" then
        isSameDestIP = false
        break
      end
    end
    if isSameDestIP then
      pfw_columns[7] = {
        header = T"Destination IP",
        name = "destinationip",
        param = "dest_ip",
        type = "text",
        attr = { input = { class="span2", value = text_destIP, id="destinationipInput" }},
      }
    end
    for _, hostWANPort in ipairs(updatedPortlist) do
     if text_WANPort == hostWANPort[2] then
        isSameWANPort = false
        break
      end
    end
     for _, hostLANPort in ipairs(updatedPortlist) do
     if text_LANPort == hostLANPort[2] then
        isSameLANPort = false
        break
      end
    end
    if isSameWANPort then
      pfw_columns[4] = {
        header = T"WAN port",
        name = "wanport",
        param = "src_dport",
        type = "text",
        attr = { input = { class="span1", value = text_WANPort, id="wanportInput" }},
        }
    end
    if isSameLANPort then
      pfw_columns[5] = {
        header = T"LAN port",
        name = "lanport",
        param = "dest_port",
        type = "text",
        attr = { input = { class="span1", value = text_LANPort, id="lanportInput" }},
        }
    end
  end
 end
end

-- Ipv6 data retrieval - Start
-- Useful pieces of transformer data for ipv6
local ipv6Data = {
  -- is IPv6 enabled on the LAN
  dhcpv6Enabled = "uci.dhcp.dhcp.@lan.dhcpv6",
  ipv6Status = "rpc.network.interface.@wan6.ip6addr",
  raEnabled = "uci.dhcp.dhcp.@lan.ra",
  pinholeEnabled = "uci.firewall.rulesgroup.@pinholerules.enabled",
}
content_helper.getExactContent(ipv6Data)

local ipv6wan2lanEnable = get_ipv6_wan2lan()

-- for drop down selector and validation
local protocolList_v6 = {
  { "tcp", T"TCP" },
  { "udp", T"UDP"},
  { "tcpudp", T"TCP/UDP"},
--{ "udplite", T"UDPLite"}, -- doesn't exist
  { "icmpv6", T"ICMPv6"},
--{ "esp", T"ESP"},  -- fails
--{ "ah", T"AH"},  -- fails
--{ "sctp", T"SCTP"}, -- fails
  { "all", T"All"}
}

-- ipv6 handleTableQuery parameter to match columns to rpc table data
-- ipv6 Firewall forwarding rules
local pfw_v6_columns = {
  {
    header = "",
    name = "enabled_v6",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" } }
  },
  {
    header = T"Name",
    name = "name",
    param = "name",
    type = "text",
    unique = true,
    attr = { input = { class="span2" } },
  },
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto.@1.value",
    default = "tcp",
    type = "select",
    values = protocolList_v6,
    attr = { select = { class="span2" } },
  },
  {
    header = T"Destination port",
    name = "wanport",
    param = "dest_port",
    type = "select",
    values = updatedPortlist,
    attr = { select = { class="span1"}},
  },
  {
    header = T"Source IP",
    name = "src_ip_v6",
    param = "src_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="39" , id = "sourceip"} },
  },
  {
    header = T"Destination IP",
    name = "dest_ip_v6",
    param = "dest_ip",
    values = new_dest_v6,
    type = "select",
    attr = { select = { class="span2" }},
  },
  {
    header = T"Destination MAC",
    name = "destinationmac_v6",
    param = "dest_mac",
    type = "text",
    readonly = true,
    attr = {  },
  },
}

-- ipv6 handleTableQuery parameter to specify transformer table to use
local pfw_v6_options = {
  tableid = "fwrules_v6",
  basepath = "rpc.network.firewall.pinholerule.",
  createMsg = T"Add new IPv6 forwarding rule",
  sorted = "name",
  newList = knownapps,
  valid = rulesDuplicateCheck
}

-- ipv6 handleTableQuery parameter filter callback to only show ipv6 rules ...
-- and only user created rules
-- return true if entry should be displayed
local function pfw_v6_filter(data)
  if (showIPv6DMZ and data.name == "DMZ IPv6 Rule" and data.dest_port == "") then
    return false
  end
  -- check handled only to display the destination IPv6 address in destination field of portmap rule
  data.dest_ip = data.dest_ip .. " "
  if post_helper.isFeatureEnabled("ipv6wan2lan") then
    if ipv6wan2lanEnable == "0" then
      if (data.target == "ACCEPT" and
        data.src == wanIntf and
        data.dest == "lan" and
        data.family == "ipv6") then
        return true
      end
    else
      if (data.target == "DROP" and
        data.src == wanIntf and
        data.dest == "lan" and
        data.family == "ipv6") then
        return true
      end
    end
  else
    if (data.target == "ACCEPT" and
      data.src == wanIntf and
      data.dest == "lan" and
      data.family == "ipv6") then
      return true
    end
  end

  return false
end

-- ipv6 handleTableQuery parameter for default values when adding entry
local pfw_v6_defaultObject = {
  target = "ACCEPT",
  src = wanIntf,
  dest = "lan",
  family = "ipv6"
}

if post_helper.isFeatureEnabled("ipv6wan2lan") then
  if ipv6wan2lanEnable == "0" then
    pfw_v6_defaultObject["target"] = "ACCEPT"
  else
    pfw_v6_defaultObject["target"] = "DROP"
  end
end

local function validateIPv6Port(_, data)
  if post_helper.getVariantValue(variantHelper, "IPv6Port") then
    if data.protocol == "icmpv6" or data.protocol == "all" then
      return true
    end
  end
  return false
end

local function sourceIPv6Validation(value, object, key)
  local success, errmsg = post_helper.validateIPAndSubnet(6)(value, object, key)
  if success then
    local ipAddress, _ = match(string.untaint(value), "^([^/]+)/?(%d*)$")
    success, errmsg = validateStringIPv6(ipAddress, object, key)
    if not success then
      return nil, errmsg
    end
  elseif value == "" then
    return true
  else
    return nil, errmsg
  end
  return true
end

-- ipv6 handleTableQuery parameter to check validity of new entry values
-- every editable column needs a validity check function
local pfw_v6_valid = {
  enabled_v6 = validateBoolean,
  name = getValidateName,
  protocol = validateEnum(protocolList_v6),
  wanport = orValidation(validateIPv6Port, andValidation(validatePortRange, isPortAndProtoReserved)),
  src_ip_v6 = sourceIPv6Validation,
  dest_ip_v6 = andValidation(validateStringIPv6, validateNotSameSourceAndDestinationIP)
}

-- ipv6 pull in all the data for the display
local pfw_v6_data, pfw_v6_helpmsg = post_helper.handleTableQuery(pfw_v6_columns, pfw_v6_options, pfw_v6_filter, pfw_v6_defaultObject, pfw_v6_valid)

local isValidationv6Error = false
if pfw_v6_helpmsg and next(pfw_v6_helpmsg) then
 isValidationv6Error = true
end

if ngx.var.request_method == "POST" then
 local post_data = ngx.req.get_post_args()
 if post_data.tableid == "fwrules_v6" then
  if isValidationv6Error then
    pfw_v6_columns[4] = {
      header = T"Destination port",
      name = "wanport",
      param = "dest_port",
      type = "text",
      attr = { input = { class="span1", value = post_data.wanport, id = "wanportInput"}},
    }
    pfw_v6_columns[6] = {
      header = T"Destination IP",
      name = "dest_ip_v6",
      param = "dest_ip",
      type = "text",
      attr = { input = { class="span2", value = post_data.dest_ip_v6 , id = "destinationIPInput"}},
    }
  end
  if (post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT") then
    local index = tonumber(post_data.index)
    local text_destIP_v6 = pfw_v6_data[index][6]
    local text_WANPort_v6 = pfw_v6_data[index][4]
    local isSameDestIP_v6 = true
    local isSameWANPort_v6 = true
    text_destIP_v6 = text_destIP_v6:match("([^%s]+)") or ""
    for _, hostDestIP in ipairs(new_dest_v6) do
     if string.find(hostDestIP[1], text_destIP_v6) or text_destIP_v6 == "unknown" then
        isSameDestIP_v6 = false
        break
     end
    end
    if isSameDestIP_v6 then
      pfw_v6_columns[6] = {
        header = T"Destination IP",
        name = "dest_ip_v6",
        param = "dest_ip",
        type = "text",
        attr = { input = { class="span2", value = text_destIP_v6, id = "destinationIPInput"}},
      }
    end
    for _, hostWANPort in ipairs(updatedPortlist) do
     if text_WANPort_v6 == hostWANPort[2] then
        isSameWANPort_v6 = false
        break
      end
    end
    if isSameWANPort_v6 then
      pfw_v6_columns[4] = {
        header = T"Destination port",
        name = "wanport",
        param = "dest_port",
        type = "text",
        attr = { input = { class="span1", value = text_WANPort_v6, id = "wanportInput"}},
      }
    end
  end
 end
end



-- Ipv6 data retrieval - End


-- UPnP forwarding rules
local upnp_columns = {
  {
    header = T"Protocol",
    name = "protocol",
    param = "proto",
    default = "tcp",
    type = "select",
    values = {
      { "tcp", "TCP"},
      { "udp", "UDP"},
      { "tcpudp", "TCP+UDP"}
    },
    attr = { select = { class="span2" } },
  },
  {
    header = T"WAN port",
    name = "wanport",
    param = "src_dport",
    type = "text",
    attr = { input = { class="span1", maxlength="5" } },
  },
  {
    header = T"LAN port",
    name = "lanport",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="5" } },
  },
  {
    header = T"Source IP",
    name = "sourceip",
    param = "remote_host",
    type = "text",
    attr = { input = { class="span2", maxlength="15" } },
  },
  {
    header = T"Destination",
    name = "destinationip",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"} },
  },
  {
    header = T"Description",
    name = "description",
    param = "description",
    type = "text",
    attr = { input = { class="span2", maxlength="15"} },
  },
}

local upnp_options = {
  canEdit = false,
  canAdd = false,
  canDelete = false,
  tableid = "upnpportforwarding",
  basepath = "sys.upnp.redirect."
}

local upnp_data, upnp_helpmsg = post_helper.handleTableQuery(upnp_columns, upnp_options, nil, nil, nil)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"WAN services", true, true))  ngx.print('\
<style>\
  .tooltip-inner {\
    max-width: 100% !important;\
  }\
</style>\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/wanservices-modal.lp">\
    ');  
      ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      lp.setpath("/www/snippets/")
      lp.include("tabs-wanservices.lp")
      ngx.print('\
    ');  if post_helper.getVariantValue(variantHelper, "DMZ", session:getrole()) then   ngx.print('\
      <fieldset class="advanced hide">\
        <legend>');  ngx.print( T"DMZ" ); ngx.print('</legend>\
        ');  
          -- Switch for toggling DMZ state
          local dmzipattr = {
            autocomplete = hosts_ac
          }
          local DMZ_destinationmac = {
            "rpc.network.firewall.dmz.redirect.dest_mac",
          }
          content_helper.getExactContent(DMZ_destinationmac)
          ngx.print(ui_helper.createSwitch(T"Enabled", "DMZ_enable", qry_data["DMZ_enable"], nil, qry_helpmsg["DMZ_enable"]),
                    ui_helper.createInputText(T"Destination IP", "DMZ_destinationip", qry_data["DMZ_destinationip"], dmzipattr, qry_helpmsg["DMZ_destinationip"]),
                    ui_helper.createLabel(T"Destination MAC", DMZ_destinationmac[1]))
          ngx.print('\
      </fieldset>\
    ');  end   ngx.print('\
\
    <fieldset>\
      <legend>');  ngx.print( T"IPv4 Port forwarding table" ); ngx.print('</legend>\
      ');  
        ngx.print(ui_helper.createTable(pfw_columns, pfw_data, pfw_options, nil, pfw_helpmsg))
        ngx.print(ui_helper.createAlertBlock(format("%s <strong>\":\"</strong> %s",T"To use port ranges use",  T"for example 500:505."), { alert = { class="alert alert-range hide" , id="portRange4" }}))
        ngx.print('\
    </fieldset>\
\
    ');  
    if ipv6Data.dhcpv6Enabled == "server" and ipv6Data.raEnabled == "server" and ipv6Data.pinholeEnabled == "1" and post_helper.isFeatureEnabled("wanServicesIpv6Portforwarding", role) then
      ngx.print('\
    ');  if post_helper.isFeatureEnabled("ipv6wan2lan") then   ngx.print('\
      <fieldset>\
        <legend>');  ngx.print( T"IPv6 Wan To Lan Access" ); ngx.print('</legend>\
        ');  
          --Switch for toggling DMZ state
          ngx.print(ui_helper.createSwitch(T"Enabled", "ipv6wan2lan", ipv6wan2lanEnable))
          ngx.print('\
      </fieldset>\
    ');  end   ngx.print('\
    <fieldset>\
      ');  if post_helper.isFeatureEnabled("ipv6wan2lan") then   ngx.print('\
        ');  if ipv6wan2lanEnable == "0" then   ngx.print('\
          <legend>');  ngx.print( T"IPv6 forwarding table" ); ngx.print('</legend>\
        ');  else   ngx.print('\
          <legend>');  ngx.print( T"IPv6 dropping table" ); ngx.print('</legend>\
         ');  end  ngx.print('\
      ');  else   ngx.print('\
        <legend>');  ngx.print( T"IPv6 forwarding table" ); ngx.print('</legend>\
      ');  end   ngx.print('\
        ');  
          local ipv6_dmz_enable_attr = {
            group = {
              style= "pointer-events: none; opacity: 0.5;"
            }
          }
          -- magic
          -- display/edit all the retrieved ipv6 firewall rule data
          if showIPv6DMZ and ipv6Data.ipv6Status == "" then
            ngx.print(ui_helper.createTable(pfw_v6_columns, pfw_v6_data, pfw_v6_options, ipv6_dmz_enable_attr, pfw_v6_helpmsg))
            ngx.print(ui_helper.createAlertBlock(T"Warning! IPv6 address is currently not available"))
          else
            ngx.print(ui_helper.createTable(pfw_v6_columns, pfw_v6_data, pfw_v6_options, nil, pfw_v6_helpmsg))
          end
          ngx.print(ui_helper.createAlertBlock(format("%s <strong>\":\"</strong> %s", T"To use port ranges use", T"for example 500:505."), { alert = { class="alert alert-range hide" , id="portRange6" }}))
          ngx.print('\
      </fieldset>\
    ');  
    end
      ngx.print('\
\
    <fieldset>\
      <legend>');  ngx.print( T"UPnP" ); ngx.print('</legend>\
      ');  
        local advanced = { group = { class = "advanced hide" }}
        ngx.print(
          ui_helper.createSwitch(T"UPnP Enabled", "upnp_status", qry_data["upnp_status"], advanced, qry_helpmsg["upnp_status"]),
          ui_helper.createSwitch(T"NAT-PMP Enabled", "upnp_natpmp", qry_data["upnp_natpmp"], advanced, qry_helpmsg["upnp_natpmp"]),
          ui_helper.createSwitch(T"Secure Mode Enabled", "upnp_secure_mode", qry_data["upnp_secure_mode"], advanced, qry_helpmsg["upnp_secure_mode"]),
          ui_helper.createInputSelect(T"Datamodel Version", "upnp_igd_version", igd_select, qry_data.upnp_igd_version, advanced),
          ui_helper.createLabel(T"", T"Note: Datamodel version <b>1</b> may be required for older applications.", {span = {class = "span12 advanced hide"},}),
          ui_helper.createTable(upnp_columns, upnp_data, upnp_options, nil, upnp_helpmsg)
        )
        ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
\
<script>\
var sourceIPValue = ');  ngx.print(sourceIPValue); ngx.print(';\
var IPv6Port = ');  ngx.print(post_helper.getVariantValue(variantHelper, "IPv6Port")); ngx.print(';\
</script>\
<script src="/js/wanservices.js"></script>\
'); 