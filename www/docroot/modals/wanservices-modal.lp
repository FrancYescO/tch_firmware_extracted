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
local table, ipairs, tonumber, match = table, ipairs, tonumber, string.match

local ddns_supported_services = {}

local function generate_ddns_supported_services()
    -- open the supported services file that come with the ddns package
    local f = io.open("/etc/ddns/services", "r")
    if f then
        for line in f:lines() do
           --a service in this file is  indicated as a url between quotes, we want a list with urls and name of service in capitals
           local service = line:match('^%b""')
           if service then
               service = service:gsub('"','')
               local serviceline = { service , service:upper() }
               ddns_supported_services[#ddns_supported_services + 1] = serviceline
           end
        end
        f:close()
    end
end

generate_ddns_supported_services()

local function validateStringPort(value,data,key)
    value = value and match(value, "^%s*(%d+)%s*$")
    local port = value and tonumber(value)
    if port and 0 < port and port < 65536 then
        if data and key then
            data[key] = value
        end
        return true
    end
    return nil, T"Port is invalid. It should be between 1 and 65535 or it must be of format port1:port2 or port1-port2."
end

-- This API validates the Firewall Port ranges and allows in the format Port1:Port2 or Port1-Port2
local portrange_pattern = "^%s*(%d+)[%-%:](%d+)$"
local function validateStringIsPortRange(value,data,key)
    if not value then
        return nil, T"Invalid port range."
    end
    local p1, p2 = match(value, portrange_pattern)
    p1 = tonumber(p1)
    p2 = tonumber(p2)
    if p1 then
      if 0 < p1 and p1 < 65536 and 0 < p2 and p2 < 65536 then
        if p1 <= p2 then
            data[key] = value
            return true
        else
          return nil, T"Port is invalid. Port1 must be less than or equal to Port2"
        end
      else
        return nil, T"Port is invalid. Port range should be between 1 and 65535"
      end
    else
      return validateStringPort(value,data,key)
    end
end

-- Retrieve GW IP + netmask for use by validation function
local ipdetails = {
    gw = "uci.network.interface.@lan.ipaddr",
    netmask = "uci.network.interface.@lan.netmask"
}
content_helper.getExactContent(ipdetails)

local ddns_status_data = {
    ddns_status = "rpc.ddns.status",
}
content_helper.getExactContent(ddns_status_data)

-- DynDNS / UPnP switches Only one handleQuery in a page
local qry_params = {
    ddns_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
    ddns_service_name = "uci.ddns.service.@myddns_ipv4.service_name",
    ddns_domain = "uci.ddns.service.@myddns_ipv4.domain",
    ddns_lookup_host = "uci.ddns.service.@myddns_ipv4.lookup_host",
    ddns_username = "uci.ddns.service.@myddns_ipv4.username",
    ddns_password = "uci.ddns.service.@myddns_ipv4.password",
    ddns_usehttps = "uci.ddns.service.@myddns_ipv4.use_https",
    ddns_cacert = "uci.ddns.service.@myddns_ipv4.cacert",
    upnp_status = "uci.upnpd.config.enable_upnp",
    upnp_natpmp = "uci.upnpd.config.enable_natpmp",
    upnp_secure_mode = "uci.upnpd.config.secure_mode",
}

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSIP = post_helper.validateStringIsPort
local vSIPR = validateStringIsPortRange
local gVP = post_helper.getValidationPassword
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local vSIIP6 = post_helper.validateStringIsIPv6
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)
local gAV = post_helper.getAndValidation

local function set_lookup_host(value, object, key)
    object["ddns_lookup_host"] = object["ddns_domain"]
    return true
end

local function set_cacert(_, object)
    object["ddns_cacert"] = "IGNORE"
    return true
end

local qry_valid = {
    ddns_enabled = vB,
    ddns_service_name = gVIPIL(gVIES(ddns_supported_services), "ddns_enabled", {"1"}),
    ddns_username = gVIPIL(vNES, "ddns_enabled", {"1"}),
    ddns_password = gVP(gVIPIL(vNES, "ddns_enabled", {"1"})),
    ddns_domain = gVIPIL(vNES, "ddns_enabled", {"1"}),
    ddns_lookup_host = set_lookup_host,
    ddns_usehttps = vB,
    ddns_cacert = set_cacert,
    upnp_status = vB,
    upnp_natpmp = vB,
    upnp_secure_mode = vB,
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

local wol = io.open("/lib/functions/firewall-wol.sh", "r")
if wol then
 if proxy.get("uci.wol.config.") then
  qry_params.WOL_enabled = "uci.wol.config.enabled"
  qry_params.WOL_port = "uci.wol.config.src_dport"
  qry_valid.WOL_enabled = vB
  qry_valid.WOL_port = vSIP
 end
 wol:close()
end

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)

local action
if ngx.var.request_method == "POST" then
action = ngx.req.get_post_args().action
end

local ddns_status = "error"
local ddns_update_info = "No error received from server"

if qry_data.ddns_enabled ~= "1" then
  ddns_status = "disabled"
else
  if action == "SAVE" then
    ddns_status = "updating"
  elseif ddns_status_data.ddns_status then
    if ddns_status_data.ddns_status == "Domain's IP updated" then
      ddns_status = "updated"
    elseif ddns_status_data.ddns_status == "No error received from server" then
      ddns_status = "updating"
    else
      ddns_status = "error"
    end

    ddns_update_info = ddns_status_data.ddns_status
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

local function globalValid(data)
    local tcp = {}
    local udp = {}
    local p1,p2
    local err, msg

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

local function getValidateName(value)
  if #value == 0 or #value > 63 then
    return nil, T"A name must be between 1 and 63 characters"
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
    destinationip = vSIDIP,
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

local pfw_options = {
    tableid = "portforwarding",
    basepath = "rpc.network.firewall.portforward.",
    createMsg = T"Add new IPv4 port mapping",
    newList = knownapps,
    valid = globalValid,
    sorted = "name"
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
    dest_ip_v6 = vSIIP6,
}

-- ipv6 pull in all the data for the display
local pfw_v6_data, pfw_v6_helpmsg = post_helper.handleTableQuery(pfw_v6_columns, pfw_v6_options, pfw_v6_filter, pfw_v6_defaultObject, pfw_v6_valid)

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
    <fieldset>\
      <legend>');  ngx.print( T"IPv4 Port forwarding table" ); ngx.print('</legend>\
      ');  
        ngx.print(ui_helper.createTable(pfw_columns, pfw_data, pfw_options, nil, pfw_helpmsg))
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
          ui_helper.createTable(upnp_columns, upnp_data, upnp_options, nil, upnp_helpmsg)
        )
        ngx.print('\
    </fieldset>\
\
    <fieldset>\
      <legend>');  ngx.print( T"DynDNS" ); ngx.print('</legend>\
      ');  
         ngx.print(
            ui_helper.createLight(T"Status", nil, ddns_state_map[ddns_status], { light = { class = ddns_light_map[ddns_status] } }),
            ui_helper.createSwitch(T"Enabled", "ddns_enabled", qry_data["ddns_enabled"], nil, qry_helpmsg["ddns_enabled"]),
            ui_helper.createInputSelect(T"Service Name", "ddns_service_name", ddns_supported_services, qry_data["ddns_service_name"], nil, qry_helpmsg["ddns_service_name"]),
            ui_helper.createSwitch(T"HTTPS", "ddns_usehttps", qry_data["ddns_usehttps"], nil, qry_helpmsg["ddns_usehttps"]),
            ui_helper.createLabel(T"", T"Note: HTTPS mode will enable encryption but not certificate-based authentication of DynDNS service", { span = {class = "span12"},}),
            ui_helper.createInputText(T"Domain", "ddns_domain", qry_data["ddns_domain"], nil, qry_helpmsg["ddns_domain"]),
            ui_helper.createInputText(T"User Name", "ddns_username", qry_data["ddns_username"], nil, qry_helpmsg["ddns_username"]),
            ui_helper.createInputPassword(T"Password", "ddns_password", qry_data["ddns_password"], nil, qry_helpmsg["ddns_password"])
          )
        if qry_data["ddns_enabled"] == "1" then
          local basic = {
            span = {
            class = "span12"
            },
          }
          ngx.print(
            ui_helper.createLabel(T"DynDNS Information", ddns_update_info, basic)
          )
        end
        ngx.print('\
    </fieldset>\
\
     ');  if wol then  ngx.print('\
      <fieldset class="advanced hide">\
        <legend>');  ngx.print( T"Wake on LAN over the Internet" ); ngx.print('</legend>\
        ');  
          ngx.print(ui_helper.createSwitch(T"Enabled", "WOL_enabled", qry_data["WOL_enabled"], nil, qry_helpmsg["WOL_enabled"]),
                    ui_helper.createInputText(T"WAN port", "WOL_port", qry_data["WOL_port"], nil, qry_helpmsg["WOL_port"]))
          ngx.print('\
      </fieldset>\
    ');  end  ngx.print('\
\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 