--pretranslated: do not change this file
 
-- Localization
-- NG-70914 modified displayed name for UPnP line 720
-- NG-92666 TI-GUI : Query : New Features added
-- NG-93922
-- GHG-3664 Introducing the Jiras (NG-70914,NG-92666,NG-93922) again based on the new Generic file from 18.1-90
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local portslist = require("portslist_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac, hosts_ac_v6 = uinetwork.getAutocompleteHostsList()
local io, pairs, string = io, pairs, string
local table, ipairs, tonumber, format, match = table, ipairs, tonumber, string.format, string.match
local role = ngx.ctx.session:getrole()

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
local vSIIP6 = post_helper.validateStringIsIPv6
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)
local gAV = post_helper.getAndValidation
local gOrV = post_helper.getOrValidation
local vQTN = post_helper.validateQTN
local gOV = post_helper.getOptionalValidation
local vSIDN = post_helper.validateStringIsDomainName
local vSIIP = post_helper.validateStringIsIP
local vSIIP4 = post_helper.validateStringIsIPv4
local validateDMZ = post_helper.validateDMZ

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

local function validate_DDNS(value, object, key)
    if vSIIP(value) then
        return post_helper.reservedIPValidation(value)
    elseif vSIDN(value) then
        return vSIDN(value)
    end
    local success, errmsg = gOrV(vSIDN, vSIIP)(value)
    if not success then
        return nil, errmsg
    end
end

local qry_valid = {
    DMZ_enable = vB,
    DMZ_destinationip = validateDMZ,
    upnp_status = vB,
    upnp_natpmp = vB,
    upnp_secure_mode = vB,
    upnp_igd_version = gVIES(igd_select),
    ddnsv4_enabled = vB,
    ddnsv4_service_name = gAV(gVIPIL(gOrV(vSIDN, vSIIP), "ddnsv4_enabled", {"1"}), gVIPIL(gVIES(valid_ipv4_services), "ddnsv4_enabled", {"1"})),
    ddnsv4_username = gAV(gVIPIL(vNES, "ddnsv4_enabled", {"1"}), post_helper.isSpaceInString),
    ddnsv4_password = gAV(gVP(gVIPIL(vNES, "ddnsv4_enabled", {"1"})), post_helper.isSpaceInString),
    ddnsv4_domain = gVIPIL(gOrV(vSIDN, vSIIP), "ddnsv4_enabled", {"1"}),
    ddnsv4_lookup_host = set_lookup_hostv4,
    ddnsv4_usehttps = vB,
    ddnsv4_cacert = set_cacertv4,
}

local ddns_ipv6_valid = {
    ddnsv6_enabled = vB,
    ddnsv6_service_name = gAV(gVIPIL(gOrV(vSIDN, vSIIP6), "ddnsv6_enabled", {"1"}), gVIPIL(gVIES(valid_ipv6_services), "ddnsv6_enabled", {"1"})),
    ddnsv6_username = gAV(gVIPIL(vNES, "ddnsv6_enabled", {"1"}), post_helper.isSpaceInString),
    ddnsv6_password = gAV(gVP(gVIPIL(vNES, "ddnsv6_enabled", {"1"})), post_helper.isSpaceInString),
    ddnsv6_domain = gVIPIL(gOrV(vSIDN, vSIIP6), "ddnsv6_enabled", {"1"}),
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
local del_pfw_data = {}

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

if not qry_data.upnp_igd_version or qry_data.upnp_igd_version == "" then
  qry_data.upnp_igd_version = "igdv2"
end

local ddns_ipv4_status, ddns_ipv4_update_info

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
  ddns_ipv4_status, ddns_ipv4_update_info = get_ddns_status("myddns_ipv4", qry_data.ddnsv4_enabled)
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
local function table_removekey(portRemoveList, key)
   local element = portRemoveList[key]
   portRemoveList[key] = nil
   return element
end

local wan_app = {}
-- Retrieve all wan-services sections in system config
local servicesTable = proxy.getPN("uci.system.wan-service.", true)
if servicesTable then
  for _,service in ipairs(servicesTable) do
    local port = match(service.path, "uci%.system%.wan%-service%.@([^%.]+)%.")
    if port then
      wan_app[#wan_app + 1 ] = port
    end
  end
end

local wan_ports ={}
-- Retrieve the list of ports in all wan-services section
for _,app in ipairs(wan_app) do
  local wan_port_path = "uci.system.wan-service.@".. app .. ".ports"
  wan_ports[#wan_ports + 1 ] = proxy.get(wan_port_path)
 end

local reserved_ports = {}
for _,wanPort in ipairs(wan_ports) do
    for port in wanPort[1].value:gmatch("%w+") do
       reserved_ports [#reserved_ports +1] = port
    end
end

--Remove the ports configured in system.wan-service in allowed_portlist
local allowed_portlist = portslist
for _,wanPort in ipairs(reserved_ports) do
  for i,j in pairs(allowed_portlist) do
    if wanPort and (tonumber(wanPort) == tonumber(j)) then
       table_removekey(allowed_portlist,i)
    end
  end
end

-- Function to check the port are reserved or not while adding the port mapping rule.
local function allowed_ports()
  return function(ports, postdata, key)
    for _,wanPort in ipairs(reserved_ports) do
        if wanPort and (wanPort == ports) then
        return nil, T"Ports already Reserved"
      end
    end
    return true
  end
end

local knownapps = require("pfwd_helper")

local pfw_helper_map = {}

pfw_helper_map["FTP server"] = {pfw = "FTP server", helper = "ftp", wanport = "21"}
pfw_helper_map["TFTP server"] = {pfw = "TFTP server", helper = "tftp", wanport = "69"}
pfw_helper_map["PPTP"] = {pfw = "PPTP", helper = "pptp", wanport = "1723"}


local portrange_pattern = "^(%d+)%:(%d+)$"
local function compare_startport(a,b)
  return a.startPort < b.startPort
end

local function validPorts(ports)
    local curend = -1
    local upnp_list = "sys.upnp.redirect."
    local upnp_params = content_helper.convertResultToObject(upnp_list, proxy.get(upnp_list))
    for _, v in ipairs(ports) do
      local wanPortStart = tonumber(v.startPort)
      local wanPortEnd = tonumber(v.endPort)
      local lanPortStart = tonumber(v.lanPortStart)
      local lanPortEnd = tonumber(v.lanPortEnd)
      if not (lanPortEnd - lanPortStart == wanPortEnd - wanPortStart) then
        return nil, { lanport = T"Port Ranges must be equal length" }
      end
      for _, l in ipairs(upnp_params) do
        l.proto = string.lower(l.proto)
        if v.portProtocol == l.proto or v.portProtocol =="tcpudp" then
          l.src_dport = tonumber(l.src_dport)
          l.dest_port = tonumber(l.dest_port)
          local lanCheck = l.dest_ip == v.dest_ip_ipv4 and (l.dest_port >= v.lanPortStart and l.dest_port <= v.lanPortEnd)
          local wanCheck = l.src_dport >= wanPortStart and l.src_dport <= wanPortEnd
          if lanCheck and wanCheck then
            return nil, {lanport = T"An existing UPNP mapping overlaps with the entered ports range", wanport = T"An existing UPNP mapping overlaps with the entered ports range"}
          elseif lanCheck then
            return nil, {lanport = T"An existing UPNP mapping overlaps with the entered ports range"}
          elseif wanCheck then
            return nil, {wanport = T"An existing UPNP mapping overlaps with the entered ports range"}
          end
        end
      end
      if v.startPort <= curend then
        return nil, { wanport = T"An existing mapping overlaps with the ports range" }
      else
        curend = v.endPort
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


local function globalValid(data)
    local tcp = {}
    local udp = {}
    local p1,p2
    local err, msg

    local allowedIndexes
    if del_pfw_index ~= nil then
        del_pfw_data, allowedIndexes = content_helper.loadTableData("rpc.network.firewall.portforward.", pfw_columns, nil, "name")
    end

    for i,v in ipairs(data) do
    if v[3] and v[4] then
        local wanChunks = { v[4]:match(portrange_pattern) }
        if #wanChunks == 2 then
            p1 = tonumber(wanChunks[1])
            p2 = tonumber(wanChunks[2])
        else
            p1 = tonumber(v[4])
            p2 = p1
        end

        local lanChunks = { v[5]:match(portrange_pattern) }
        if #lanChunks == 2 then
            p3 = tonumber(lanChunks[1])
            p4 = tonumber(lanChunks[2])
        else
            p3 = tonumber(v[5])
            p4 = p3
        end

        local proto = v[3]
        local destIP_ipv4 = v[7]
        if proto == "tcp" or proto == "tcpudp" then
            tcp[#tcp+1] = { startPort = p1, endPort = p2, lanPortStart = p3, lanPortEnd = p4, index = i, portProtocol = proto, dest_ip_ipv4 = destIP_ipv4 }
        end
        if proto == "udp" or proto == "tcpudp" then
            udp[#udp+1] = { startPort = p1, endPort = p2, lanPortStart = p3, lanPortEnd = p4, index = i, portProtocol = proto, dest_ip_ipv4 = destIP_ipv4 }
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

local protocolList = {
    { "tcp", "TCP"},
    { "udp", "UDP"},
    { "tcpudp", "TCP+UDP"}
}

local pfw_valid = {
    enabled = vB,
    name = getValidateName,
    lanport = vSIPR,
    wanport = gAV(vSIPR,allowed_ports()),
    destinationip = gAV(vSIDIP,vQTN, post_helper.reservedIPValidation),
    protocol = gVIES(protocolList),
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
    local path = "uci.firewall.helper."
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
    dhcpv6Enabled = "uci.dhcp.dhcp.@lan.dhcpv6",
    raEnabled = "uci.dhcp.dhcp.@lan.ra",
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
    unique = true,
    attr = { input = { class="span1", maxlength="11" }, autocomplete=portslist },
  },
  {
    header = T"Destination IP",
    name = "dest_ip_v6",
    param = "dest_ip",
    type = "text",
    unique = true,
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

-- ipv6 handleTableQuery parameter to check validity of new entry values
-- every editable column needs a validity check function
local pfw_v6_valid = {
    enabled_v6 = vB,
    name = getValidateName,
    protocol = gVIES(protocolList_v6),
    wanport = vSIPR,
    src_ip_v6 = gOV(vSIIP6),
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

local function validateDomain(value)
   if vSIIP(value) then
     return post_helper.reservedIPValidation(value)
   end
   return vSIDN(value)
end

local domain_valid = {
   domain = validateDomain,
}
local dnsrule_options = {
    tableid = "dnsrules",
    basepath = "uci.dhcp.dnsrule.@.",
    createMsg = T"Add new dns rule",
    sorted = dns_sort,
    objectName  = post_helper.getRandomKey(),
    addNamedObject = true
}

local dnsrule_data, dnsrule_helpmsg = post_helper.handleTableQuery(dnsrule_columns, dnsrule_options, nil, nil, domain_valid)

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

local range_warning = {
    alert = {
      class = "alert-range"
    },
}

local upnp_data, upnp_helpmsg = post_helper.handleTableQuery(upnp_columns, upnp_options, nil, nil, nil)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"WAN services", true, true))   ngx.print('\
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
');  if role == "engineer" then   ngx.print('\
    <fieldset class="advanced hide">\
      <legend>');  ngx.print( T"DNS rules" ); ngx.print('</legend>\
      ');  
        ngx.print(ui_helper.createTable(dnsrule_columns, dnsrule_data, dnsrule_options, nil, dnsrule_helpmsg))
        ngx.print('\
    </fieldset>\
');  end   ngx.print('\
\
    <fieldset>\
      <legend>');  ngx.print( T"UPnP" ); ngx.print('</legend>\
      ');  
        local advanced = { group = { class = "advanced hide" }}
        ngx.print(
          ui_helper.createSwitch(T"UPnP IGD Enabled", "upnp_status", qry_data["upnp_status"], advanced, qry_helpmsg["upnp_status"]),
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
      ');  if role == "engineer" then   ngx.print('\
        <legend>');  ngx.print( T"DynDNS IPV4" ); ngx.print('</legend>\
      ');  else   ngx.print('\
        <legend>');  ngx.print( T"DynDNS" ); ngx.print('</legend>\
      ');  end
         ngx.print(
            ui_helper.createLight(T"Status", nil, ddns_state_map[ddns_ipv4_status], { light = { class = ddns_light_map[ddns_ipv4_status] } }),
            ui_helper.createSwitch(T"Enabled", "ddnsv4_enabled", qry_data["ddnsv4_enabled"], nil, qry_helpmsg["ddnsv4_enabled"]),
            ui_helper.createInputText(T"Service Name", "ddnsv4_service_name", qry_data["ddnsv4_service_name"], {autocomplete = ddns_ipv4_supported_services}, qry_helpmsg["ddnsv4_service_name"]),
            ui_helper.createSwitch(T"HTTPS", "ddnsv4_usehttps", qry_data["ddnsv4_usehttps"], nil, qry_helpmsg["ddnsv4_usehttps"]),
            ui_helper.createLabel(T"", T"Note: HTTPS mode will enable encryption but not certificate-based authentication of DynDNS service", { span = {class = "span12"},}),
            ui_helper.createInputText(T"Domain", "ddnsv4_domain", qry_data["ddnsv4_domain"], nil, qry_helpmsg["ddnsv4_domain"]),
            ui_helper.createInputText(T"User Name", "ddnsv4_username", qry_data["ddnsv4_username"], nil, qry_helpmsg["ddnsv4_username"]),
            ui_helper.createInputPassword(T"Password", "ddnsv4_password", qry_data["ddnsv4_password"], nil, qry_helpmsg["ddnsv4_password"])
        )
        if qry_data["ddnsv4_enabled"] == "1" then
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
      if role == "engineer" then
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
    ');  end   ngx.print('\
\
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
\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
\
<script>\
  $(function(){\
    var ddnsv4_status = $("#ddnsv4_enabled").val();\
    var ddnsv6_status = $("#ddnsv6_enabled").val();\
\
    if (ddnsv4_status == 1) {\
      $("#ddnsv4_service_name").parent().parent().removeClass("hide");\
      $("#ddnsv4_domain").parent().parent().removeClass("hide");\
      $("#ddnsv4_username").parent().parent().removeClass("hide");\
      $("#ddnsv4_password").parent().parent().removeClass("hide");\
    }\
    else {\
      $("#ddnsv4_service_name").parent().parent().addClass("hide");\
      $("#ddnsv4_domain").parent().parent().addClass("hide");\
      $("#ddnsv4_username").parent().parent().addClass("hide");\
      $("#ddnsv4_password").parent().parent().addClass("hide");\
    }\
\
    if (ddnsv6_status == 1) {\
      $("#ddnsv6_service_name").parent().parent().removeClass("hide");\
      $("#ddnsv6_domain").parent().parent().removeClass("hide");\
      $("#ddnsv6_username").parent().parent().removeClass("hide");\
      $("#ddnsv6_password").parent().parent().removeClass("hide");\
    }\
    else {\
      $("#ddnsv6_service_name").parent().parent().addClass("hide");\
      $("#ddnsv6_domain").parent().parent().addClass("hide");\
      $("#ddnsv6_username").parent().parent().addClass("hide");\
      $("#ddnsv6_password").parent().parent().addClass("hide");\
    }\
\
    $("#ddnsv4_enabled").change(function() {\
      var ddnsv4_status = $("#ddnsv4_enabled").val();\
      if (ddnsv4_status == 1) {\
        $("#ddnsv4_service_name").parent().parent().removeClass("hide");\
        $("#ddnsv4_domain").parent().parent().removeClass("hide");\
        $("#ddnsv4_username").parent().parent().removeClass("hide");\
        $("#ddnsv4_password").parent().parent().removeClass("hide");\
      }\
      else{\
        $("#ddnsv4_service_name").parent().parent().addClass("hide");\
        $("#ddnsv4_domain").parent().parent().addClass("hide");\
        $("#ddnsv4_username").parent().parent().addClass("hide");\
        $("#ddnsv4_password").parent().parent().addClass("hide");\
       }\
    });\
\
    $("#ddnsv6_enabled").change(function() {\
      var ddnsv6_status = $("#ddnsv6_enabled").val();\
      if (ddnsv6_status == 1) {\
        $("#ddnsv6_service_name").parent().parent().removeClass("hide");\
        $("#ddnsv6_domain").parent().parent().removeClass("hide");\
        $("#ddnsv6_username").parent().parent().removeClass("hide");\
        $("#ddnsv6_password").parent().parent().removeClass("hide");\
      }\
      else {\
        $("#ddnsv6_service_name").parent().parent().addClass("hide");\
        $("#ddnsv6_domain").parent().parent().addClass("hide");\
        $("#ddnsv6_username").parent().parent().addClass("hide");\
        $("#ddnsv6_password").parent().parent().addClass("hide");\
      }\
    });\
\
  });\
</script>\
'); 