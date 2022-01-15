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
local uinetwork = require("web.uinetwork_helper")
local hosts_ac, hosts_ac_v6 = uinetwork.getAutocompleteHostsList()
local io, pairs, string = io, pairs, string
local table, ipairs, tonumber, format, match = table, ipairs, tonumber, string.format, string.match
local role = ngx.ctx.session:getrole()

local new_dest_v4, new_dest_v6 = {}, {}
for key,value in pairs(hosts_ac) do
  new_dest_v4[#new_dest_v4+1] = {value,key}
end

for key,value in pairs(hosts_ac_v6) do
  new_dest_v6[#new_dest_v6+1] = {value,key}
end

local igd_select = {
    { "igdv1", T'1'},
    { "igdv2", T'2'}
}

local function generate_ddns_supported_services(name)
    -- open the supported services file that come with the ddns package
    local ddns_supported_services , valid_services = {}, {}
    local path = format("/etc/ddns/%s", name)
    local ddnsFile = io.open(path, "r")
    if ddnsFile then
        for line in ddnsFile:lines() do
            --a service in this file is  indicated as a url between quotes, we want a list with urls and name of service in capitals
            local service = line:match('^%b""')
            if service then
                service = service:gsub('"','')
                ddns_supported_services[service] = service
                valid_services[#valid_services + 1] = { service }
            end
        end
        ddnsFile:close()
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
    ddns_status = "rpc.ddns.status"
}

local qry_params = {
    DMZ_enable = "rpc.network.firewall.dmz.enable",
    DMZ_destination = "rpc.network.firewall.dmz.redirect.dest_ip",
    upnp_status = "uci.upnpd.config.enable_upnp",
    upnp_natpmp = "uci.upnpd.config.enable_natpmp",
    upnp_secure_mode = "uci.upnpd.config.secure_mode",
    upnp_igd_version = "uci.upnpd.config.datamodel_version"
}

local ddns_ipv4_params = {
    ddnsv4_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
    ddnsv4_service_name = "uci.ddns.service.@myddns_ipv4.service_name",
    ddnsv4_domain = "uci.ddns.service.@myddns_ipv4.domain",
    ddnsv4_lookup_host = "uci.ddns.service.@myddns_ipv4.lookup_host",
    ddnsv4_username = "uci.ddns.service.@myddns_ipv4.username",
    ddnsv4_password = "uci.ddns.service.@myddns_ipv4.password",
    ddnsv4_usehttps = "uci.ddns.service.@myddns_ipv4.use_https",
    ddnsv4_cacert = "uci.ddns.service.@myddns_ipv4.cacert"
}

local ddns_ipv6_params = {
    ddnsv6_enabled = "uci.ddns.service.@myddns_ipv6.enabled",
    ddnsv6_service_name = "uci.ddns.service.@myddns_ipv6.service_name",
    ddnsv6_domain = "uci.ddns.service.@myddns_ipv6.domain",
    ddnsv6_lookup_host = "uci.ddns.service.@myddns_ipv6.lookup_host",
    ddnsv6_username = "uci.ddns.service.@myddns_ipv6.username",
    ddnsv6_password = "uci.ddns.service.@myddns_ipv6.password",
    ddnsv6_usehttps = "uci.ddns.service.@myddns_ipv6.use_https",
    ddnsv6_cacert = "uci.ddns.service.@myddns_ipv6.cacert"
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
local function validateDomainName(value)
  if vSIIP(value) then
    if vSIIP4(value) or vSIIP6(value) then
      return gAV(post_helper.reservedIPValidation, post_helper.validateLXC)(value)
    end
  end
  return vSIDN(value)
end

local qry_valid = {
    DMZ_enable = vB,
    DMZ_destination = gVIPIL(vSIDIP, "DMZ_enable", {"1"}),
    upnp_status = vB,
    upnp_natpmp = vB,
    upnp_secure_mode = vB,
    upnp_igd_version = gVIES(igd_select)
}

local ddns_ipv4_valid = {
    ddnsv4_enabled = vB,
    ddnsv4_service_name = gAV(gVIPIL(gAV(validateDomainName), "ddnsv4_enabled", {"1"}), gVIPIL(gVIES(valid_ipv4_services), "ddnsv4_enabled", {"1"})),
    ddnsv4_username = gAV(gVIPIL(vNES, "ddnsv4_enabled", {"1"}), post_helper.isSpaceInString),
    ddnsv4_password = gAV(gVP(gVIPIL(vNES, "ddnsv4_enabled", {"1"})), post_helper.isSpaceInString),
    ddnsv4_domain = gVIPIL(gAV(validateDomainName), "ddnsv4_enabled", {"1"}),
    ddnsv4_lookup_host = set_lookup_hostv4,
    ddnsv4_usehttps = vB,
    ddnsv4_cacert = set_cacertv4
}

local ddns_ipv6_valid = {
    ddnsv6_enabled = vB,
    ddnsv6_service_name = gAV(gVIPIL(gAV(validateDomainName), "ddnsv6_enabled", {"1"}), gVIPIL(gVIES(valid_ipv6_services), "ddnsv6_enabled", {"1"})),
    ddnsv6_username = gAV(gVIPIL(vNES, "ddnsv6_enabled", {"1"}), post_helper.isSpaceInString),
    ddnsv6_password = gAV(gVP(gVIPIL(vNES, "ddnsv6_enabled", {"1"})), post_helper.isSpaceInString),
    ddnsv6_domain = gVIPIL(gAV(validateDomainName), "ddnsv6_enabled", {"1"}),
    ddnsv6_lookup_host = set_lookup_hostv6,
    ddnsv6_usehttps = vB,
    ddnsv6_cacert = set_cacertv6
}

local ddns_state_map = {
    disabled = T"disabled",
    updating = T"updating",
    updated = T"updated",
    error = T"error"
}

local ddns_light_map = {
    disabled = "off",
    updating = "orange",
    updated = "green",
    error = "red"
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

local function get_ddns_status(service_name, ddns_enabled)
    local status = ddns_status_data.ddns_status
    local ddns_status = "error"
    local ddns_update_info = "No error received from server"
    local service_status
    local action
    if status then
        for statusString in string.gmatch(status, '([^%]]+)') do
            service_status = match(statusString, service_name .. "%[(.+)")
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
    for _, service in ipairs(servicesTable) do
        local port = match(service.path, "uci%.system%.wan%-service%.@([^%.]+)%.")
        if port then
            wan_app[#wan_app + 1 ] = port
        end
    end
end

local wan_ports = {}
-- Retrieve the list of ports in all wan-services section
for _, app in ipairs(wan_app) do
    local wan_port_path = "uci.system.wan-service.@".. app .. ".ports"
    wan_ports[#wan_ports + 1 ] = proxy.get(wan_port_path)
end

local reserved_ports = {}
for _, wanPort in ipairs(wan_ports) do
    for port in wanPort[1].value:gmatch("%w+") do
        reserved_ports [#reserved_ports +1] = port
    end
end

--Remove the ports configured in system.wan-service in allowed_portlist
local allowed_portlist = portslist
for _, wanPort in ipairs(reserved_ports) do
    for allowedPortList, allowedPortListValue in pairs(allowed_portlist) do
        if wanPort and (tonumber(wanPort) == tonumber(allowedPortListValue)) then
            table_removekey(allowed_portlist,allowedPortList)
        end
    end
end

-- Function to check the port are reserved or not while adding the port mapping rule.
local function allowed_ports()
    return function(ports, postdata, key)
        local portStart, portEnd = string.match(ports, "^(%d+):(%d+)$")
        if not portStart then
            portStart, portEnd = ports, ports
        end
        for _,wanPort in ipairs(reserved_ports) do
            if wanPort >= portStart and wanPort <= portEnd  then
                return nil, T"Ports already Reserved"
            end
        end
        return true
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

local dmz_destination_values = (function ()
    local values = {}
    values[1]={"0", T"Add user defined entry"}
    for name, ip in pairs(hosts_ac) do
       values[#values + 1] = { ip, name }
    end
    return values
end)()

local portrange_pattern = "^(%d+)[%-%:](%d+)$"
local function compare_startport(first, second)
    return first.startPort < second.startPort
end

local function validPorts(ports)
    local curend = -1
    local upnp_list = "sys.upnp.redirect."
    local upnp_params = content_helper.convertResultToObject(upnp_list, proxy.get(upnp_list))
    for _, portsValue in ipairs(ports) do
        local wanPortStart = tonumber(portsValue.startPort)
        local wanPortEnd = tonumber(portsValue.endPort)
        local lanPortStart = tonumber(portsValue.lanStartPort)
        local lanPortEnd = tonumber(portsValue.lanEndPort)
        if wanPortStart <= 8090 and 8090 <= wanPortEnd then
            return nil, { wanport = T"8090 is Remote GUI Port" }
        end
        if not (lanPortEnd - lanPortStart == wanPortEnd - wanPortStart) then
            return nil, { lanport = T"Port Ranges must be equal length" }
        end
        for _, upnpParam in ipairs(upnp_params) do
            upnpParam.proto = string.lower(upnpParam.proto)
            if portsValue.portProtocol == upnpParam.proto or portsValue.portProtocol == "tcpudp" then
                upnpParam.src_dport = tonumber(upnpParam.src_dport)
                upnpParam.dest_port = tonumber(upnpParam.dest_port)
                local lanCheck = upnpParam.dest_ip == portsValue.dest_ip_ipv4 and (upnpParam.dest_port >= lanPortStart and upnpParam.dest_port <= lanPortEnd)
                local wanCheck = upnpParam.src_dport >= wanPortStart and upnpParam.src_dport <= wanPortEnd
                if lanCheck and wanCheck then
                    return nil, {lanport = T"An existing UPNP mapping overlaps with the entered ports range", wanport = T"An existing UPNP mapping overlaps with the entered ports range"}
                elseif lanCheck then
                    return nil, {lanport = T"An existing UPNP mapping overlaps with the entered ports range"}
                elseif wanCheck then
                    return nil, {wanport = T"An existing UPNP mapping overlaps with the entered ports range"}
                end
            end
        end
        if portsValue.startPort <= curend then
            return nil, { wanport = T"An existing mapping overlaps with the ports range" }
        else
            curend = portsValue.endPort
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
        attr = { input = { class = "span2" } }
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
        attr = { select = { class = "span2" } }
    },
    {
        header = T"WAN port",
        name = "wanport",
        param = "src_dport",
        type = "text",
        attr = { input = { class = "span1", maxlength = "11" }, autocomplete = allowed_portlist }
    },
    {
        header = T"LAN port",
        name = "lanport",
        param = "dest_port",
        type = "text",
        attr = { input = { class = "span1", maxlength = "11" }, autocomplete = portslist }
    },
    {
        header = T"Source IP",
        name = "sourceip",
        param = "src_ip",
        type = "text",
        attr = { input = { class = "span2", maxlength = "15" } }
    },
    {
        header = T"Destination IP",
        name = "destinationip",
        param = "dest_ip",
        type = "select",
	values = new_dest_v4,
	attr = { select = { class="span2"}}
    },
    {
        header = T"Destination MAC",
        name = "destinationmac",
        param = "dest_mac",
        type = "text",
        readonly = true,
        attr = {  }
    }
}

------------Firewall forwarding rules check and handle
local protocolMap = {
    DirectX = {"tcp", "udp", "tcpudp", "udp"},
    eMule = {"tcp", "tcp", "tcp", "udp", "udp"},
    Netmeeting = {"tcp", "tcp", "tcp", "tcp", "tcp", "tcp", "udp"},
    PlayStation = {"tcp", "tcp", "tcp", "tcpudp", "udp", "udp"},
    Skype = {"tcp", "tcpudp", "tcpudp"},
    Vuze = {"tcp", "tcp", "tcp", "udp", "udp"},
    Wii = {"tcpudp", "tcpudp", "tcp", "tcpudp", "tcp"},
    WindowsLiveMessenger = {"tcpudp", "tcpudp", "tcpudp", "tcp", "tcpudp", "tcp", "tcp", "tcpudp", "tcpudp","udp", "udp"},
    WinMX = {"tcp", "udp"},
}

local function isMultiPort(ports)
    local pos, _ = string.find(ports, ",")
    if pos ~= nil then
        return true
    end
    return false
end

local function getPortList(ports)
    local portList = {}
    local i,j, check=1,1,nil
    while true do
        check, j = string.find(ports, ",", i)
        local port = string.gsub(string.sub(ports, i, j), ",", "")
        table.insert(portList, port)
        if not check then break end
        i = j+1
    end
    return portList
end

local function getTcpUdpPortRangeList(wanPort, lanport, proto, dest_ip, idx, tcp, udp)
    local p1,p2,p3,p4
    local wanchunks = { wanPort:match(portrange_pattern) }
    if #wanchunks == 2 then
        p1 = tonumber(wanchunks[1])
        p2 = tonumber(wanchunks[2])
    else
        p1 = tonumber(wanPort)
        p2 = p1
    end
    local lanchunks = { lanport:match(portrange_pattern) }
    if #lanchunks == 2 then
        p3 = tonumber(lanchunks[1])
        p4 = tonumber(lanchunks[2])
    else
        p3 = tonumber(lanport)
        p4 = p3
    end
    if proto == "tcp" or proto == "tcpudp" then
        tcp[#tcp+1] = { startPort = p1, endPort = p2, index = idx, lanStartPort = p3, lanEndPort = p4, portProtocol = proto, dest_ip_ipv4 = dest_ip }
    end
    if proto == "udp" or proto == "tcpudp" then
        udp[#udp+1] = { startPort = p1, endPort = p2, index = idx, lanStartPort = p3, lanEndPort = p4, portProtocol = proto, dest_ip_ipv4 = dest_ip}
    end
    return tcp, udp
end

local function globalValid(data)
    local tcp = {}
    local udp = {}
    local err, msg
    local idx=1

    local allowedIndexes
    if del_pfw_index ~= nil then
        del_pfw_data, allowedIndexes = content_helper.loadTableData("rpc.network.firewall.portforward.", pfw_columns, nil, "name")
    end
    for i,v in ipairs(data) do
        local name = v[2]
        local protocol = v[3]
        local wanPortStr = v[4]
        local lanPortStr = v[5]
        local dest_ip = v[7]
        if isMultiPort(wanPortStr) then
            wanPortList = getPortList(wanPortStr)
            lanPortList = getPortList(lanPortStr)
            for j=1, #wanPortList do
                local protocolMapName = string.format("%s",string.gsub(name, " ", ""))
                if protocolMap[protocolMapName] ~= nil then
                    protocol = protocolMap[protocolMapName][j]
                end
                getTcpUdpPortRangeList(wanPortList[j], lanPortList[j], protocol, dest_ip, idx, tcp, udp)
                idx = idx + 1
            end
        else
            getTcpUdpPortRangeList(wanPortStr, lanPortStr, protocol, dest_ip, idx, tcp, udp)
            idx = idx + 1
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

local function validateNotSameSourceAndDestinationIP(value, object)
    local errmsg = T"Source IP cannot be same as Destination IP"
    if object.tableid == "portforwarding" then
        if object.destinationip == object.sourceip then
            return nil, errmsg
        end
    end
    if object.tableid == "fwrules_v6" then
        if object.dest_ip_v6 == object.src_ip_v6 then
            return nil, errmsg
        end
    end
    return true
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

local function isSamePortAndIP(value, object)
    local pinholerule_list = "rpc.network.firewall.pinholerule."
    local pinhole_params = content_helper.convertResultToObject(pinholerule_list, proxy.get(pinholerule_list))
    for _, pinHoleValue in ipairs(pinhole_params) do
        if pinHoleValue.dest_port == object.wanport and pinHoleValue.dest_ip == object.dest_ip_v6 then
            return nil,T"duplicate value"
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
        return nil,T"Cannot use GatewayIP address range"
    end
    local success, errmsg = post_helper.isNetworkAddress(ipaddr, ipdetails.netmask)
    if success then
        return nil, T"Cannot use the network address"
    end
    return true
end

local function validatePort(value, object, key, wan)
    local key_init = key
    local replacedash
    if isMultiPort(value) then
        local portList= getPortList(value)
        for i=1, #portList do
            replacedash=string.gsub(portList[i],"-",":")
            key=key_init..tostring(i)
            local valid, helpmsg = post_helper.validateStringIsPortRange(replacedash,object,key)
            if valid == nil then
                return valid, helpmsg
            elseif wan == true then
                return validateServicePort(replacedash)
            end
        end
    else
        if string.match(value,"%-") then
            key=key_init.."valid"
        end
        replacedash=string.gsub(value,"-",":")
        local valid, helpmsg = post_helper.validateStringIsPortRange(replacedash, object, key)
        if valid == nil then
            return valid, helpmsg
        elseif wan == true then
            return validateServicePort(replacedash)
        end
    end
    return true
end

local pfw_valid = {
    enabled = vB,
    name = getValidateName,
    lanport = validatePort,
    wanport = gAV(validatePort,allowed_ports()),
    sourceip = gOV(gAV(vSIIP4, vQTN, vLXC, post_helper.reservedIPValidation, post_helper.advancedIPValidation, sourceIPCheck)),
    destinationip = gAV(vSIDIP, vQTN, vLXC, post_helper.reservedIPValidation, validateNotSameSourceAndDestinationIP),
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
    target = "DNAT"
}

local function set_helper_port(helper, port)
    local path = "uci.firewall.helper."
    local data = proxy.get(path)
    if data == nil then
        return
    end
    for _, portValue in ipairs(data) do
        if portValue.param == "helper" and portValue.value == helper then
            proxy.set(portValue.path .. "dest_port", port)
            return
        end
    end
end

local function get_firewall_helper(userredir_name)
    local tmp
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

local function columnsToParamMapCusto(columns, sub)
    local map = {}
    for _,v in ipairs(columns) do
        if v.type == "aggregate" then
            for _, values in ipairs(v.subcolumns) do
                if sub or not values.readonly then
                    map[values.name] = values.param
                end
            end
        else
            if sub or not v.readonly then
                map[v.name] = v.param
            end
        end
    end
    return map
end

function convertPostToArrayCusto(columns, data)
    local line = {}
    for _,v in ipairs(columns) do
        if v.type == "aggregate" then
            line[#line+1] = convertPostToArrayCusto(v.subcolumns, data)
        else
            line[#line+1] = data[v.name]
        end
    end
    return line
end

local function validatePortRange(basepath, columns, filter, sorted, content)
    local data, allowedIndexes = content_helper.loadTableData(basepath, columns, filter, sorted)
    data[#data+1] = convertPostToArrayCusto(columns, content)
    return globalValid(data)
end

function validateRuleName(value)
    local helpmsg = {}
    if type(value) ~= "string" and not string.istainted(value) then
        helpmsg["name"]=T"Received a non string value"
        return nil, helpmsg
    end
    if #value == 0 then
        helpmsg["name"]=T"String cannot be empty"
        return nil, helpmsg
    end
    local basepath = "rpc.network.firewall.portforward."
    local contentmatch = content_helper.getMatchedContent(basepath, { ["name"] = value })
    if #contentmatch > 0 then
        helpmsg["name"]=T"duplicate value"
        return nil, helpmsg
    end
    return true
end

local function complementObjectAndValidateCusto(postdata, mapparam, mapvalid)
    for k,v in pairs(mapparam) do
        if not postdata[k] then
            postdata[k] = "" -- put a default value to get it through validation, it should have been sent in the post data
        end
    end
    return content_helper.validateObject(postdata, mapvalid)
end

--handles set function only when more than 2 non-consecutive ports defined under ipv4 port forwarding rule
local function handleTableQueryMultiPorts(columns, options, filter, defaultObject, mapValidation)
    local content = ngx.req.get_post_args()
    local paramMap = columnsToParamMapCusto(columns)
    local basepath = options.basepath or ""
    local session = ngx.ctx.session
    local tablesessionkey = options.tableid .. ".stateid"
    local tablesessionindexes = options.tableid .. ".allowedindexes"
    local sorted = options and options.sorted
    local wanPortList= getPortList(content.wanport)
    local lanPortList= getPortList(content.lanport)
    local multiName = content.name
     -- validated stores status of different validation happens step by step before setting values in config file
    local validated, helpmsg = complementObjectAndValidateCusto(content, paramMap, mapValidation)
    if multiName then
        if validated == true then
            for i=1, #wanPortList do
                local name = multiName .." ".. tostring(i)
                validated, helpmsg = validateRuleName(name)
                if not validated then
                    break
                end
            end
        end
        if validated == true then
            validated, helpmsg = validatePortRange(basepath, columns, filter, sorted, content)
        end
        if validated == true then
            if isMultiPort(content.wanport) then
                for i=1, #wanPortList do
                    content.name = multiName .." ".. tostring(i)
                    content.wanport = wanPortList[i]
                    content.lanport = lanPortList[i]
                    local protocolMapName = string.format("%s",string.gsub(multiName, " ", ""))
                    if protocolMap[protocolMapName] ~= nil then
                        content.protocol = protocolMap[protocolMapName][i]
                    end
                    success = content_helper.addNewObject(basepath, content, paramMap, defaultObject)
                end
                proxy.apply()
            end
        end
    end
    options.stateid = session:retrieve(tablesessionkey) or ""
    local data, allowedIndexes = content_helper.loadTableData(basepath, columns, filter, sorted)
    session:store(tablesessionindexes, allowedIndexes)
    if not validated then
        options.editing = -1
        for _,v in ipairs(columns) do
            v.default = content[v.name] or v.default or ""
        end
    end
    return data, helpmsg
end

--pfw_data and pfw_helpmsg stores the set value and response message while set action happpens respectively, which is used while creating the table
local pfw_data, pfw_helpmsg
local isSingleHandle = true
if ngx.var.request_method == "POST" then
    local content = ngx.req.get_post_args()
    if content.action == "TABLE-DELETE" and content.tableid == "portforwarding" then
        del_pfw_index = tonumber(content.index)
    end
    if content.action == "TABLE-ADD" and content.tableid == "portforwarding" and isMultiPort(content.wanport) then
        if content.tableid == "portforwarding" then
            pfw_data, pfw_helpmsg = handleTableQueryMultiPorts(pfw_columns, pfw_options, pfw_filter, pfw_defaultObject, pfw_valid)
        end
        isSingleHandle = false
    end
end

if isSingleHandle then
    pfw_data, pfw_helpmsg = post_helper.handleTableQuery(pfw_columns, pfw_options, pfw_filter, pfw_defaultObject, pfw_valid)
end
-- Ipv6 data retrieval - Start

-- Useful pieces of transformer data for ipv6
local ipv6Data = {
    -- is IPv6 enabled on the LAN
    dhcpv6Enabled = "uci.dhcp.dhcp.@lan.dhcpv6",
    raEnabled = "uci.dhcp.dhcp.@lan.ra",
    pinholeEnabled = "uci.firewall.rulesgroup.@pinholerules.enabled"
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
        attr = { input = { class = "span2" } }
    },
    {
        header = T"Protocol",
        name = "protocol",
        param = "proto.@1.value",
        default = "tcp",
        type = "select",
        values = protocolList_v6,
        attr = { select = { class = "span2" } }
    },
    {
        header = T"Destination port",
        name = "wanport",
        param = "dest_port",
        type = "text",
        attr = { input = { class = "span1", maxlength = "11" }, autocomplete = portslist }
    },
    {
        header = T"Source IP",
        name = "src_ip_v6",
        param = "src_ip",
        type = "text",
        attr = { input = { class = "span2", maxlength = "39" } }
    },
    {
        header = T"Destination IP",
        name = "dest_ip_v6",
        param = "dest_ip",
	type = "select",
        values = new_dest_v6,
        attr = { select = { class="span2"}}
    },
    {
        header = T"Destination MAC",
        name = "destinationmac_v6",
        param = "dest_mac",
        type = "text",
        readonly = true,
        attr = {  }
    }
}

-- ipv6 handleTableQuery parameter to specify transformer table to use
local pfw_v6_options = {
    tableid = "fwrules_v6",
    basepath = "rpc.network.firewall.pinholerule.",
    createMsg = T"Add new IPv6 forwarding rule",
    sorted = "name",
    newList = knownapps
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
    family = "ipv6"
}

-- ipv6 handleTableQuery parameter to check validity of new entry values
-- every editable column needs a validity check function
local pfw_v6_valid = {
    enabled_v6 = vB,
    name = getValidateName,
    protocol = gVIES(protocolList_v6),
    wanport = gAV(vSIPR, isSamePortAndIP, allowed_ports()),
    src_ip_v6 = gOV(vSIIP6),
    dest_ip_v6 = gAV(vSIIP6, validateNotSameSourceAndDestinationIP)
}

--ipv4 pull in all the data for the display
-- ipv6 pull in all the data for the display
local pfw_v6_data, pfw_v6_helpmsg = post_helper.handleTableQuery(pfw_v6_columns, pfw_v6_options, pfw_v6_filter, pfw_v6_defaultObject, pfw_v6_valid)

if ngx.var.request_method == "POST" then
 local post_data = ngx.req.get_post_args()
 if post_data.tableid == "fwrules_v6" then
  if (post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT") then
    local index = tonumber(post_data.index)
    local text_destIP_v6 = pfw_v6_data[index][6]
    local isSameDestIP_v6 = true
    for _, hostDestIP in ipairs(new_dest_v6) do
     if text_destIP_v6 == hostDestIP[1] then
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
  end
 end
end

-- Ipv6 data retrieval - End

-- DNS rules
local policy_select = {{"any", "any"}}
local outpolicy_select = {{"copy", "copy"}, {"default", "default"}}

local policy_pn = proxy.getPN("uci.mwan.policy.",true)
if policy_pn then
    for _, policyValue in ipairs(policy_pn) do
        local path = policyValue["path"]
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
    for _, interfaceValue in ipairs(intfs_pn) do
        local path = interfaceValue["path"]
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
        attr = { input = { class = "span2", maxlength = "30"} }
    },
    {
        header = T"DNS Set",
        name = "dnsset",
        param = "dnsset",
        type = "select",
        values = intfs_select,
        attr = { select = { class = "span1" } }
    },
    {
        header = T"Policy",
        name = "policy",
        param = "policy",
        type = "select",
        values = policy_select,
        attr = { select = { class = "span1" } }
    },
    {
        header = T"Out Policy",
        name = "outpolicy",
        param = "outpolicy",
        type = "select",
        values = outpolicy_select,
        attr = { select = { class = "span1" } }
    }
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

for _, dnsRuleDataValue in pairs(dnsrule_data) do
    if(dnsRuleDataValue[1] == nil or dnsRuleDataValue[1] == "") then
        dnsRuleDataValue[1] = "1"
    end
    if(dnsRuleDataValue[4] == nil or dnsRuleDataValue[4] == "") then
        dnsRuleDataValue[4] = "any"
    end
    if(dnsRuleDataValue[5] == nil or dnsRuleDataValue[5] == "") then
        dnsRuleDataValue[5] = "copy"
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
        attr = { select = { class = "span2" } }
    },
    {
        header = T"WAN port",
        name = "wanport",
        param = "src_dport",
        type = "text",
        attr = { input = { class = "span1", maxlength = "5" } }
    },
    {
        header = T"LAN port",
        name = "lanport",
        param = "dest_port",
        type = "text",
        attr = { input = { class = "span1", maxlength = "5" } }
    },
    {
        header = T"Source IP",
        name = "sourceip",
        param = "remote_host",
        type = "text",
        attr = { input = { class = "span2", maxlength = "15" } }
    },
    {
        header = T"Destination",
        name = "destinationip",
        param = "dest_ip",
        type = "text",
        attr = { input = { class = "span2", maxlength = "15"} }
    },
    {
        header = T"Description",
        name = "description",
        param = "description",
        type = "text",
        attr = { input = { class = "span2", maxlength = "15"} }
    }
}

local upnp_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "upnpportforwarding",
    basepath = "sys.upnp.redirect."
}

local range_warning = {
    alert = {
        class = "alert-range"
    }
}

local upnp_data, upnp_helpmsg = post_helper.handleTableQuery(upnp_columns, upnp_options, nil, nil, nil)

    ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"WAN services", true, true))   ngx.print('\
\
<div class = "modal-body update">\
    <form class = "form-horizontal" method = "post" action = "modals/wanservices-modal.lp">\
    ');
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
\
    <fieldset class = "advanced hide">\
      <legend>');  ngx.print( T"DMZ" ); ngx.print('</legend>\
      ');
        -- Switch for toggling DMZ state
	local dmzattr = {
          autocomplete = hosts_ac
        }
        local dmzattr_sel = {
          select = {
            class = "span5",
          },
        }
        local dmzattr_hide = {
          autocomplete = hosts_ac,
          input = {
            class = "hide ",
          },
        }
        ngx.print(ui_helper.createSwitch(T"Enabled", "DMZ_enable", qry_data["DMZ_enable"], nil, qry_helpmsg["DMZ_enable"]))
        local sel = 0
        for _ , v in pairs(dmz_destination_values) do
          if (v[1] and qry_data["DMZ_destination"] and (qry_data["DMZ_destination"] == v[1])) then
            sel = 1
            break
          end
        end

        ngx.print(ui_helper.createInputSelect(T"Destination", "DMZ_destination_sel",dmz_destination_values, qry_data["DMZ_destination"], dmzattr_sel))
        if sel == 0 then
          ngx.print(ui_helper.createInputText(T"", "DMZ_destination", qry_data["DMZ_destination"], dmzattr, qry_helpmsg["DMZ_destination"]))
        else
          ngx.print(ui_helper.createInputText(T"", "DMZ_destination", qry_data["DMZ_destination"], dmzattr_hide, qry_helpmsg["DMZ_destination"]))
        end
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
    if ipv6Data.dhcpv6Enabled == "server" and ipv6Data.raEnabled == "server" and ipv6Data.pinholeEnabled == "1" then
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
        $("#portforwarding").find("th:eq(5)").addClass("advanced hide");\
        $("#portforwarding tbody tr").find("td:eq(5)").addClass("advanced hide");\
        $("#fwrules_v6").find("th:eq(4)").addClass("advanced hide");\
        $("#fwrules_v6 tbody tr").find("td:eq(4)").addClass("advanced hide");\
        $("#upnpportforwarding").find("th:eq(3)").addClass("advanced hide");\
        $("#upnpportforwarding tbody tr").find("td:eq(3)").addClass("advanced hide");\
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
    $(\'select[name="DMZ_destination_sel"]\').on("change", function() {\
      if(this.value == "0") {\
        $(\'input[name="DMZ_destination"]\').val("");\
        $(\'input[name="DMZ_destination"]\').show();\
      }else{\
        $(\'input[name="DMZ_destination"]\').val(this.value);\
        $(\'input[name="DMZ_destination"]\').hide();\
      }\
    });\
\
    $("[name =\'dest_ip_v6\']").change(function () {\
      if ($("#dest_ip_v6").val() == "custom") {\
        $("#dest_ip_v6").replaceWith($(\'<input/>\',{\'type\':\'text\', \'name\':\'dest_ip_v6\',\'id\' : \'dest_ip_v6Input\'}));\
      }\
    });\
    $("[name =\'destinationip\']").change(function () {\
      if ($("#destinationip").val() == "custom") {\
        $("#destinationip").replaceWith($(\'<input/>\',{\'type\':\'text\', \'name\':\'destinationip\',\'id\' : \'destinationipInput\'}));\
      }\
    });\
\
});\
</script>\
');
