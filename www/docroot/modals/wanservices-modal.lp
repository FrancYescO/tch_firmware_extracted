--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local portslist = require("portslist_helper")
local wanservices = require("webui_core.wanservices")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac, hosts_ac_v6 = uinetwork.getAutocompleteHostsList()
local io, pairs, string = io, pairs, string
local table, ipairs, tonumber, format, match = table, ipairs, tonumber, string.format, string.match
local currentuserrole = ngx.ctx.session:getrole()
local dnsrule_data, dnsrule_helpmsg
local alg_data, alg_helpmsg
local nat_data, nat_helpmsg

local igd_select = {
    { "igdv1", T'1'},
    { "igdv2", T'2'},
}

local function generate_ddns_supported_services(name)
    -- open the supported services file that come with the ddns package
    local ddns_supported_services , valid_services = {}, {}
    local path = format("/etc/ddns/%s", name)
    local f = io.open(path, "r")
    if f then
        for line in f:lines() do
            --a service in this file is  indicated as a url between quotes, we want a list with urls and name of service in capitals
            local service = line:match('^%b""')
            if service then
                service = service:gsub('"','')
                ddns_supported_services[service] = service
                valid_services[#valid_services + 1] ={ service }
            end
        end
        f:close()
    end
    return ddns_supported_services, valid_services
end

local ddns_ipv4_supported_services , valid_ipv4_services = generate_ddns_supported_services("services")
local ddns_ipv6_supported_services , valid_ipv6_services = generate_ddns_supported_services("services_ipv6")

-- Retrieve GW IP + netmask for use by validation function
local ipdetails = {
    gw = "uci.network.interface.@lan.ipaddr",
    netmask = "uci.network.interface.@lan.netmask"
}
content_helper.getExactContent(ipdetails)

local ddns_ipv4_path = "uci.ddns.service.@myddns_ipv4."
local ddns_ipv6_path = "uci.ddns.service.@myddns_ipv6."
local ddns_ipv4 = proxy.get(ddns_ipv4_path)
local ddns_ipv6 = proxy.get(ddns_ipv6_path)

local ddns_status_data = {
    ddns_status = "rpc.ddns.status",
}

-- DMZ / DynDNS / UPnP switches Only one handleQuery in a page
local qry_params = {
    DMZ_enable = "rpc.network.firewall.dmz.enable",
    DMZ_destinationip = "rpc.network.firewall.dmz.redirect.dest_ip",
    upnp_status = "uci.upnpd.config.enable_upnp",
    upnp_natpmp = "uci.upnpd.config.enable_natpmp",
    upnp_secure_mode = "uci.upnpd.config.secure_mode",
    upnp_igd_version = "uci.upnpd.config.datamodel_version",
}

local ddns_ipv4_params = {
    ddnsv4_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
    ddnsv4_service_name = "uci.ddns.service.@myddns_ipv4.service_name",
    ddnsv4_domain = "uci.ddns.service.@myddns_ipv4.domain",
    ddnsv4_lookup_host = "uci.ddns.service.@myddns_ipv4.lookup_host",
    ddnsv4_username = "uci.ddns.service.@myddns_ipv4.username",
    ddnsv4_password = "uci.ddns.service.@myddns_ipv4.password",
    ddnsv4_usehttps = "uci.ddns.service.@myddns_ipv4.use_https",
    ddnsv4_cacert = "uci.ddns.service.@myddns_ipv4.cacert",
}

local ddns_ipv6_params = {
    ddnsv6_enabled = "uci.ddns.service.@myddns_ipv6.enabled",
    ddnsv6_service_name = "uci.ddns.service.@myddns_ipv6.service_name",
    ddnsv6_domain = "uci.ddns.service.@myddns_ipv6.domain",
    ddnsv6_lookup_host = "uci.ddns.service.@myddns_ipv6.lookup_host",
    ddnsv6_username = "uci.ddns.service.@myddns_ipv6.username",
    ddnsv6_password = "uci.ddns.service.@myddns_ipv6.password",
    ddnsv6_usehttps = "uci.ddns.service.@myddns_ipv6.use_https",
    ddnsv6_cacert = "uci.ddns.service.@myddns_ipv6.cacert",
}

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSIP = post_helper.validateStringIsPort
local vSIPR = post_helper.validateStringIsPortRange
local gVP = post_helper.getValidationPassword
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local vSIIP6 = post_helper.validateStringIsIP(6)
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)
local gAV = post_helper.getAndValidation
local gOrV = post_helper.getOrValidation
local vQTN = post_helper.validateQTN
local vSIDN = post_helper.validateStringIsDomainName
local vSIIP = post_helper.validateStringIsIP()
local validateDMZ = post_helper.validateDMZ
local validateIsSpace = post_helper.isSpaceInString
local isPortAndProtoReserved, reserved_ports = wanservices.isPortAndProtoReserved()

local function set_lookup_hostv4(value, object, key)
    object["ddnsv4_lookup_host"] = object["ddnsv4_domain"]
    return true
end

local function set_lookup_hostv6(value, object, key)
    object["ddnsv6_lookup_host"] = object["ddnsv6_domain"]
    return true
end

local function set_cacertv4(_, object)
    object["ddnsv4_cacert"] = "IGNORE"
    return true
end

local function set_cacertv6(_, object)
    object["ddnsv6_cacert"] = "IGNORE"
    return true
end

local qry_valid = {
    DMZ_enable = vB,
    DMZ_destinationip = validateDMZ,
    upnp_status = vB,
    upnp_natpmp = vB,
    upnp_secure_mode = vB,
    upnp_igd_version = gVIES(igd_select),
}

local ddns_ipv4_valid = {
    ddnsv4_enabled = vB,
    ddnsv4_service_name = gAV(gVIPIL(gOrV(vSIDN, vSIIP), "ddnsv4_enabled", {"1"}), gVIPIL(gVIES(valid_ipv4_services), "ddnsv4_enabled", {"1"})),
    ddnsv4_username = gVIPIL(gAV(vNES,validateIsSpace), "ddnsv4_enabled", {"1"}),
    ddnsv4_password = gVP(gVIPIL(gAV(vNES,validateIsSpace), "ddnsv4_enabled", {"1"})),
    ddnsv4_domain = gAV(gOrV(vSIDN, vSIIP), gVIPIL(vNES, "ddnsv4_enabled", {"1"})),
    ddnsv4_lookup_host = set_lookup_hostv4,
    ddnsv4_usehttps = vB,
    ddnsv4_cacert = set_cacertv4,
}

local ddns_ipv6_valid = {
    ddnsv6_enabled = vB,
    ddnsv6_service_name = gAV(gVIPIL(gOrV(vSIDN, vSIIP6), "ddnsv6_enabled", {"1"}), gVIPIL(gVIES(valid_ipv6_services), "ddnsv6_enabled", {"1"})),
    ddnsv6_username = gVIPIL(gAV(vNES,validateIsSpace), "ddnsv6_enabled", {"1"}),
    ddnsv6_password = gVP(gVIPIL(gAV(vNES,validateIsSpace), "ddnsv6_enabled", {"1"})),
    ddnsv6_domain = gAV(gOrV(vSIDN, vSIIP6), gVIPIL(vNES, "ddnsv6_enabled", {"1"})),
    ddnsv6_lookup_host = set_lookup_hostv6,
    ddnsv6_usehttps = vB,
    ddnsv6_cacert = set_cacertv6,
}

local ddns_state_map = {
  disabled = T"disabled",
  updating = T"updating",
  updated = T"updated",
  error = T"error",
}

local ddns_light_map = {
  disabled = "off",
  updating = "orange",
  updated = "green",
  error = "red",
}

local del_pfw_index = nil

local wol = proxy.get("uci.wol.proxy.@wan2lan.")
if wol then
  qry_params.WOL_enable = "uci.wol.proxy.@wan2lan.enable"
  qry_params.WOL_src_port = "uci.wol.proxy.@wan2lan.src_port"
  qry_params.WOL_dest_port = "uci.wol.proxy.@wan2lan.dest_port"
  qry_valid.WOL_enable = vB
  qry_valid.WOL_src_port = vSIP
  qry_valid.WOL_dest_port = vSIP
end

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)

local ddns_ipv4_data, ddns_ipv4_helpmsg
local ddns_ipv4_status, ddns_ipv4_update_info

if ddns_ipv4 then
  ddns_ipv4_data, ddns_ipv4_helpmsg = post_helper.handleQuery(ddns_ipv4_params, ddns_ipv4_valid)
end

local ddns_ipv6_data, ddns_ipv6_helpmsg
local ddns_ipv6_status, ddns_ipv6_update_info

if ddns_ipv6 then
  ddns_ipv6_data, ddns_ipv6_helpmsg = post_helper.handleQuery(ddns_ipv6_params, ddns_ipv6_valid)
end

content_helper.getExactContent(ddns_status_data)
local status = ddns_status_data.ddns_status

local function get_ddns_status(service_name, ddns_enabled)
  local ddns_status = "error"
  local ddns_update_info = "No error received from server"
  local service_status

  if status then
    for x in string.gmatch(status, '([^%]]+)') do
      service_status = match(x, service_name .. "%[(.+)")
      if service_status then
        break
      end
    end
  end
  if ddns_enabled ~= "1" then
    ddns_status = "disabled"
  else
    if action == "SAVE" then
      ddns_status = "updating"
    elseif service_status then
      if service_status == "Domain's IP updated" then
        ddns_status = "updated"
      elseif service_status == "No error received from server" then
        ddns_status = "updating"
      else
        ddns_status = "error"
      end

      ddns_update_info = format("%s", service_status)
    end
  end
  return ddns_status, ddns_update_info
end

if ddns_ipv4 then
  ddns_ipv4_status, ddns_ipv4_update_info = get_ddns_status("myddns_ipv4", ddns_ipv4_data.ddnsv4_enabled)
end

if ddns_ipv6 then
  ddns_ipv6_status, ddns_ipv6_update_info = get_ddns_status("myddns_ipv6", ddns_ipv6_data.ddnsv6_enabled)
end

local action
if ngx.var.request_method == "POST" then
  action = ngx.req.get_post_args().action
  local content = ngx.req.get_post_args()

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
local function table_removekey(table, key)
   local element = table[key]
   table[key] = nil
   return element
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

local pfw_helper_map = {}
pfw_helper_map["FTP server"] = {pfw = "FTP server", helper = "ftp", wanport = "21"}
pfw_helper_map["TFTP server"] = {pfw = "TFTP server", helper = "tftp", wanport = "69"}
pfw_helper_map["PPTP"] = {pfw = "PPTP", helper = "pptp", wanport = "1723"}


local portrange_pattern = "^(%d+)%:(%d+)$"
local function compare_startport(a,b)
  return a.start < b.start
end

local function validPorts(ports)
    local curend = -1

    for _,v in ipairs(ports) do
        if v.start <= curend then
            return nil, { wanport = T"An existing mapping overlaps with the ports range" }
        else
            curend = v["end"]
        end
    end
    return true
end


-- Firewall forwarding rules
local pfw_columns = {
  {
    header = "",
    name = "enabled",
    param = "enabled",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
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
    type = "text",
    attr = { input = { class="span1", maxlength="11" }, autocomplete=allowed_portlist },
  },
  {
    header = T"LAN port",
    name = "lanport",
    param = "dest_port",
    type = "text",
    attr = { input = { class="span1", maxlength="11" }, autocomplete=portslist },
  },
  {
    header = T"Destination IP",
    name = "destinationip",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15" }, autocomplete=hosts_ac },
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
    basepath = "sys.upnp.redirect.",
}

local upnp_data, upnp_helpmsg = post_helper.handleTableQuery(upnp_columns, upnp_options, nil, nil, nil)

local function globalValid(data)
    local tcp = {}
    local udp = {}
    local p1,p2
    local err, msg

    -- Adding UPnP ports if any, to avoid duplicate ports in ipv4 pfw
    if #upnp_data ~= nil then
        for i,v in ipairs(upnp_data) do
            if v[1] == "TCP" or v[1] == "TCP+UDP" then
                tcp[#tcp+1] = { start = tonumber(v[2]), ["end"] = tonumber(v[3]), index = i }
            end
            if v[1] == "UDP" or v[1] == "TCP+UDP" then
                udp[#udp+1] = { start = tonumber(v[2]), ["end"] = tonumber(v[3]), index = i }
            end
        end
    end

    local allowedIndexes
    if del_pfw_index ~= nil then
        del_pfw_data, allowedIndexes = content_helper.loadTableData("rpc.network.firewall.portforward.", pfw_columns, nil, "name")
    end

    for i,v in ipairs(data) do
    if v[3] and v[4] then
        local chunks = { v[4]:match(portrange_pattern) }
        if #chunks == 2 then
            p1 = tonumber(chunks[1])
            p2 = tonumber(chunks[2])
        else
            p1 = tonumber(v[4])
            p2 = p1
        end

        local proto = v[3]
        if proto == "tcp" or proto == "tcpudp" then
            tcp[#tcp+1] = { start = p1, ["end"] = p2, index = i }
        end
        if proto == "udp" or proto == "tcpudp" then
            udp[#udp+1] = { start = p1, ["end"] = p2, index = i }
        end
    end
    end

    table.sort(tcp, compare_startport)
    table.sort(udp, compare_startport)

    err, msg = validPorts(tcp)
    if not err then
        return err, msg
    end
    err, msg = validPorts(udp)

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
  if match(value, "[^%w%-%s]") then
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
  for row = 1, #object do
    for n = row+1, #object do
      if object[n][3] ~= "icmpv6" and object[n][3] ~= "all" and object[row][3] ~= "icmpv6" and object[row][3] ~= "all" then
        if isIpv6DestinationsSame(object[row][5], object[n][5]) and
          isPortsOverlap(object[row][4], object[n][4]) and
          isProtocolDuplicate(object[row][3], object[n][3]) then
          return nil, {wanport = T"duplicate value"}
        end
      else
        if isIpv6DestinationsSame(object[row][5], object[n][5]) and object[row][3] == object[n][3]  then
          return nil, {protocol = T"duplicate value"}
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
local pfw_valid = {
    enabled = vB,
    name = getValidateName,
    lanport = vSIPR,
    wanport = gAV(vSIPR,isPortAndProtoReserved),
    destinationip = gAV(vSIDIP,vQTN),
    protocol = gAV(gVIES(protocolList),isPortAndProtoReserved)
}
-- ip handleTableQuery parameter filter callback to only show ipv4 port forwardings ...
-- and only user created rules
-- return true if entry should be displayed
local function pfw_filter(data)
    if (data.target == "DNAT" and
        data.src == "wan" and
        data.dest == "lan" and
        data.family == "ipv4" and data.name ~= "DMZ rule") then
        return true
    end
    return false
end

-- Warning, this uses transformer paths. So use correct naming
local pfw_defaultObject = {
    src = "wan",
    dest = "lan",
    family = "ipv4",
    target = "DNAT",
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
    local tmp
    for _,tmp in pairs(pfw_helper_map) do
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
    onDelete = onDelete,
}

local pfw_data, pfw_helpmsg = post_helper.handleTableQuery(pfw_columns, pfw_options, pfw_filter, pfw_defaultObject, pfw_valid)

-- Ipv6 data retrieval - Start
-- Useful pieces of transformer data for ipv6
local ipv6Data = {
    -- is IPv6 enabled on the LAN
    lanIpv6Enabled = "uci.network.interface.@lan.ipv6",
    pinholeEnabled = "uci.firewall.rulesgroup.@pinholerules.enabled",
}
content_helper.getExactContent(ipv6Data)
-- for drop down selector and validation
local protocolList_v6 = {
    { "tcp", T"TCP"},
    { "udp", T"UDP"},
    { "tcpudp", T"TCP/UDP"},
--  { "udplite", T"UDPLite"}, -- doesn't exist
    { "icmpv6", T"ICMPv6"},
--  { "esp", T"ESP"},  -- fails
--  { "ah", T"AH"},  -- fails
--  { "sctp", T"SCTP"}, -- fails
    { "all", T"All"},
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
    attr = { switch = { ["data-placement"] = "right" }}
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
    type = "text",
    attr = { input = { class="span1", maxlength="11" }, autocomplete=portslist },
  },
  {
    header = T"Destination IP",
    name = "dest_ip_v6",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="39" }, autocomplete=hosts_ac_v6 },
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
    if (data.target == "ACCEPT" and
        data.src == "wan" and
        data.dest == "lan" and
        data.family == "ipv6") then
        return true
    end
    return false
end
-- ipv6 handleTableQuery parameter for default values when adding entry
local pfw_v6_defaultObject = {
    target = "ACCEPT",
    src = "wan",
    dest = "lan",
    family = "ipv6",
}
local function validateIPv6Port(_, data)
  if data.protocol == "icmpv6" or data.protocol == "all" then
    return true
  end
  return false
end
-- ipv6 handleTableQuery parameter to check validity of new entry values
-- every editable column needs a validity check function
local pfw_v6_valid = {
    enabled_v6 = vB,
    name = getValidateName,
    protocol = gVIES(protocolList_v6),
    wanport = gOrV(validateIPv6Port, gAV(vSIPR,isPortAndProtoReserved)),
    dest_ip_v6 = vSIIP6,
}
-- ipv6 pull in all the data for the display
local pfw_v6_data, pfw_v6_helpmsg = post_helper.handleTableQuery(pfw_v6_columns, pfw_v6_options, pfw_v6_filter, pfw_v6_defaultObject, pfw_v6_valid)
-- Ipv6 data retrieval - End
-- DNS rules
local policy_select = {{"any", "any"}}
local outpolicy_select = {{"copy", "copy"}, {"default", "default"}}
local policy_pn = proxy.getPN("uci.mwan.policy.",true)
if policy_pn then
    for _,v in ipairs(policy_pn) do
        local path = v["path"]
        local policy_name = match(path,"@([^@%.]-)%.")
        if policy_name then
            policy_select[#policy_select + 1] = {policy_name, policy_name}
            outpolicy_select[#outpolicy_select + 1] = {policy_name, policy_name}
        end
    end
end
local intfs_select = {{"default", "default"}}
local intfs_pn = proxy.getPN("uci.network.interface.",true)
if intfs_pn then
    for _,v in ipairs(intfs_pn) do
        local path = v["path"]
        local intf_name = match(path,"@([^@%.]-)%.")
        if intf_name and intf_name ~= "loopback" and intf_name ~= "lan" then
            intfs_select[#intfs_select + 1] = {intf_name,intf_name}
        end
    end
end
local dnsrule_columns = {
  {
    header = "",
    name = "enable",
    param = "enable",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Domain",
    name = "domain",
    param = "domain",
    type = "text",
    unique = true,
    attr = { input = { class="span2", maxlength="30"} },
  },
  {
    header = T"DNS Set",
    name = "dnsset",
    param = "dnsset",
    type = "select",
    values = intfs_select,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Policy",
    name = "policy",
    param = "policy",
    type = "select",
    values = policy_select,
    attr = { select = { class="span1" } },
  },
  {
    header = T"Out Policy",
    name = "outpolicy",
    param = "outpolicy",
    type = "select",
    values = outpolicy_select,
    attr = { select = { class="span1" } },
  },
}
local function dns_sort(rule1, rule2)
  return rule1.paramindex < rule2.paramindex
end

local domain_valid = {
   domain = gOrV(vSIDN, vSIIP),
}
local dnsrule_options = {
    tableid = "dnsrules",
    basepath = "uci.dhcp.dnsrule.@.",
    createMsg = T"Add new dns rule",
    sorted = dns_sort,
    objectName  = post_helper.getRandomKey(),
    addNamedObject = true
}

if currentuserrole == "guest" then

  dnsrule_data, dnsrule_helpmsg = post_helper.handleTableQuery(dnsrule_columns, dnsrule_options, nil, nil, domain_valid)

  for k, v in pairs(dnsrule_data) do
    if(v[1] == nil or v[1] == "") then
        v[1] = "1"
    end
    if(v[4] == nil or v[4] == "") then
        v[4] = "any"
    end
    if(v[5] == nil or v[5] == "") then
        v[5] = "copy"
    end
  end
end

local function getConfPath(conf,type,name,opt)
  local pathConf = proxy.get(string.format("uci.%s.%s.",conf,type))
  local path = {}

  for pathConfKey, pathConfValue in pairs(pathConf) do
    if(pathConfValue.value == name) then
       path[#path+1] = pathConfValue.path .. opt
     end
  end
  return path
end

local alg_sip_paths = getConfPath("firewall_helpers","helper","sip","enable")
local alg_params = {}
for k,v in ipairs(alg_sip_paths) do
  alg_params["fw_alg_sip_" .. k] = v
end

local function validatAlgSip(value, object, key)
    local ok, msg = vNES(value)
    if ok then
        for k,_ in ipairs(alg_sip_paths) do
            object["fw_alg_sip_" .. k] = value
        end
        return true
    else
        return ok, msg
    end
end

local alg_valid = {
    fw_alg_sip_1 = validatAlgSip,
}

if currentuserrole == "guest" then
  alg_data, alg_helpmsg = post_helper.handleQuery(alg_params, alg_valid)
end

local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.",firewall_zone)
local zonenum = ""
for _, v in ipairs(firewall_zone_path) do
  if (v["name"] == "wan") then
    zonenum = v["paramindex"]
    break
  end
end
local firewall_forwarding = proxy.get("uci.firewall.forwarding.")
local firewall_forwarding_path = content_helper.convertResultToObject("uci.firewall.forwarding.",firewall_forwarding)
local forwdnum = ""
for _, v in ipairs(firewall_forwarding_path) do
  if (v["src"] == "wan" and v["dest"] == "lan") then
    forwdnum = v["paramindex"]
    break
  end
end
local firewall_value = {["uci.firewall.forwarding."..forwdnum..".src"] = "wan",
                        ["uci.firewall.forwarding."..forwdnum..".dest"] = "lan",
                        ["uci.firewall.forwarding."..forwdnum..".name"] = "for_w2l"}
local function validateNat(value, object, key)
  local valid, msg = post_helper.validateBoolean(value, object, key)
  if valid and zonenum ~= "" and value ~= proxy.get("uci.firewall.zone."..zonenum..".masq")[1].value then
    proxy.set("uci.firewall.zone."..zonenum..".conntrack", "1")
    if value == "1" then
      if forwdnum == "" then
        forwdnum = proxy.add("uci.firewall.forwarding.")
        proxy.set(firewall_value)
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "0")
      else
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "0")
      end
    else
      if forwdnum == "" then
        forwdnum = proxy.add("uci.firewall.forwarding.")
        proxy.set(firewall_value)
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "1")
      else
        proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "1")
      end
    end
    proxy.apply()
  end
  return valid, msg
end
-- Configurable data
local natParams = {
    uci_wan_masq = "uci.firewall.zone."..zonenum..".masq",
}

local natValid = {
    uci_wan_masq = validateNat,
}

local range_warning = {
    alert = {
      class = "alert-range"
    },
}

if currentuserrole == "guest" then
  nat_data, nat_helpmsg = post_helper.handleQuery(natParams, natValid)
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"WAN services", true, true, nil, help_link) ); ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/wanservices-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
\
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
\
    <fieldset>\
      <legend>');  ngx.print( T"IPv4 Port forwarding table" ); ngx.print('</legend>\
      ');  
        ngx.print(ui_helper.createTable(pfw_columns, pfw_data, pfw_options, nil, pfw_helpmsg))
        ngx.print(ui_helper.createAlertBlock(format("%s <strong>\":\"</strong> %s",T"To use port ranges use", T"for example 500:505."), range_warning))
        ngx.print('\
    </fieldset>\
\
    ');  
    if ipv6Data.lanIpv6Enabled ~= "0" and ipv6Data.pinholeEnabled == "1" then
      ngx.print('\
        <fieldset>\
          <legend>');  ngx.print( T"IPv6 forwarding table" ); ngx.print('</legend>\
          ');  
            -- magic
            -- display/edit all the retrieved ipv6 firewall rule data
            ngx.print(ui_helper.createTable(pfw_v6_columns, pfw_v6_data, pfw_v6_options, nil, pfw_v6_helpmsg))
            ngx.print(ui_helper.createAlertBlock(format("%s <strong>\":\"</strong> %s",T"To use port ranges use", T"for example 500:505."), range_warning))
            ngx.print('\
        </fieldset>\
    ');  
    end
      ngx.print('\
    ');  
	if currentuserrole == "guest" then
	  ngx.print('\
    <fieldset class="advanced hide">\
      <legend>');  ngx.print( T"DNS rules" ); ngx.print('</legend>\
      ');  
        ngx.print(ui_helper.createTable(dnsrule_columns, dnsrule_data, dnsrule_options, nil, dnsrule_helpmsg))
        ngx.print('\
    </fieldset>\
	');  
	end
	  ngx.print('\
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
\
    ');  
    if ddns_ipv4 ~= nil then
      ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"DynDNS IPV4" ); ngx.print('</legend>\
      ');  
         ngx.print(
            ui_helper.createLight(T"Status", nil, ddns_state_map[ddns_ipv4_status], { light = { class = ddns_light_map[ddns_ipv4_status] } }),
            ui_helper.createSwitch(T"Enabled", "ddnsv4_enabled", ddns_ipv4_data["ddnsv4_enabled"], nil, ddns_ipv4_helpmsg["ddnsv4_enabled"]),
            ui_helper.createInputText(T"Service Name", "ddnsv4_service_name", ddns_ipv4_data["ddnsv4_service_name"], {autocomplete = ddns_ipv4_supported_services}, ddns_ipv4_helpmsg["ddnsv4_service_name"]),
            ui_helper.createSwitch(T"HTTPS", "ddnsv4_usehttps", ddns_ipv4_data["ddnsv4_usehttps"], nil, ddns_ipv4_helpmsg["ddnsv4_usehttps"]),
            ui_helper.createLabel(T"", T"Note: HTTPS mode will enable encryption but not certificate-based authentication of DynDNS service", { span = {class = "span12"},}),
            ui_helper.createInputText(T"Domain", "ddnsv4_domain", ddns_ipv4_data["ddnsv4_domain"], nil, ddns_ipv4_helpmsg["ddnsv4_domain"]),
            ui_helper.createInputText(T"User Name", "ddnsv4_username", ddns_ipv4_data["ddnsv4_username"], nil, ddns_ipv4_helpmsg["ddnsv4_username"]),
            ui_helper.createInputPassword(T"Password", "ddnsv4_password", ddns_ipv4_data["ddnsv4_password"], nil, ddns_ipv4_helpmsg["ddnsv4_password"])
        )
        if ddns_ipv4_data["ddnsv4_enabled"] == "1" then
          local basic = {
            span = {
            class = "span12"
            },
          }
          ngx.print(
            ui_helper.createLabel(T"DynDNS Information", ddns_ipv4_update_info, basic)
          )
        end
        ngx.print('\
    </fieldset>\
    ');  end   ngx.print('\
    ');  
    if ddns_ipv6 ~= nil then
      ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"DynDNS IPV6" ); ngx.print('</legend>\
      ');  
         ngx.print(
            ui_helper.createLight(T"Status", nil, ddns_state_map[ddns_ipv6_status], { light = { class = ddns_light_map[ddns_ipv6_status] } }),
            ui_helper.createSwitch(T"Enabled", "ddnsv6_enabled", ddns_ipv6_data["ddnsv6_enabled"], nil, ddns_ipv6_helpmsg["ddnsv6_enabled"]),
            ui_helper.createInputText(T"Service Name", "ddnsv6_service_name", ddns_ipv6_data["ddnsv6_service_name"], {autocomplete = ddns_ipv6_supported_services}, ddns_ipv6_helpmsg["ddnsv6_service_name"]),
            ui_helper.createSwitch(T"HTTPS", "ddnsv6_usehttps", ddns_ipv6_data["ddnsv6_usehttps"], nil, ddns_ipv6_helpmsg["ddnsv6_usehttps"]),
            ui_helper.createLabel(T"", T"Note: HTTPS mode will enable encryption but not certificate-based authentication of DynDNS service", { span = {class = "span12"},}),
            ui_helper.createInputText(T"Domain", "ddnsv6_domain", ddns_ipv6_data["ddnsv6_domain"], nil, ddns_ipv6_helpmsg["ddnsv6_domain"]),
            ui_helper.createInputText(T"User Name", "ddnsv6_username", ddns_ipv6_data["ddnsv6_username"], nil, ddns_ipv6_helpmsg["ddnsv6_username"]),
            ui_helper.createInputPassword(T"Password", "ddnsv6_password", ddns_ipv6_data["ddnsv6_password"], nil, ddns_ipv6_helpmsg["ddnsv6_password"])
        )
        if ddns_ipv6_data["ddnsv6_enabled"] == "1" then
          local basic = {
            span = {
            class = "span12"
            },
          }
          ngx.print(
            ui_helper.createLabel(T"DynDNS Information", ddns_ipv6_update_info, basic)
          )
        end
        ngx.print('\
    </fieldset>\
    ');  end   ngx.print('\
    ');  if wol then  ngx.print('\
      <fieldset class="advanced hide">\
        <legend>');  ngx.print( T"Wake on LAN over the Internet" ); ngx.print('</legend>\
        ');  
          ngx.print(ui_helper.createSwitch(T"Enabled", "WOL_enable", qry_data["WOL_enable"], nil, qry_helpmsg["WOL_enable"]),
                    ui_helper.createInputText(T"WAN port", "WOL_src_port", qry_data["WOL_src_port"], nil, qry_helpmsg["WOL_src_port"]),
                    ui_helper.createInputText(T"LAN port", "WOL_dest_port", qry_data["WOL_dest_port"], nil, qry_helpmsg["WOL_dest_port"]))
          ngx.print('\
      </fieldset>\
    ');  end  ngx.print('\
    ');  if currentuserrole == "guest" then   ngx.print('\
    ');  if #alg_sip_paths > 0 then   ngx.print('\
      <fieldset>\
        <legend>');  ngx.print( T"ALG Configuration" ); ngx.print('</legend>\
        ');  
          ngx.print(ui_helper.createSwitch(T"ALG SIP", "fw_alg_sip_1", alg_data["fw_alg_sip_1"]))
		  ngx.print('\
      </fieldset>\
    ');  end   ngx.print('\
    ');  if zonenum ~= "" then   ngx.print('\
      <fieldset>\
        <legend>');  ngx.print( T"NAT Configuration" ); ngx.print('</legend>\
        ');  
          ngx.print(ui_helper.createSwitch(T"NAT", "uci_wan_masq", nat_data["uci_wan_masq"]))
		  ngx.print('\
      </fieldset>\
    ');  end   ngx.print('\
    ');  end   ngx.print('\
\
  </form>\
</div>\
\
<script>\
(function() {\
  var protocol = $("#protocol").val();\
  if (protocol == "icmpv6" || protocol == "all"){\
    $("#wanportInput").attr("readonly", "readonly");\
  }\
  $("#protocol").change(function(){\
    if (($(this).val() == "icmpv6") || ($(this).val() == "all")){\
      $("#wanport").attr("disabled", "disabled");\
      $("#wanportInput").attr("readonly", "readonly");\
      $("#wanportInput").val(\'\');\
    }\
    else {\
      $("#wanport").removeAttr("disabled");\
      $("#wanportInput").removeAttr("readonly");\
    }\
  });\
}());\
</script>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 