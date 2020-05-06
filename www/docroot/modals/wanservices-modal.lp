<%
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
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local table, ipairs, tonumber, format, match = table, ipairs, tonumber, string.format, string.match

local ddns_supported_services = {}
local match = string.match

local function generate_ddns_supported_services()
    -- open the supported services file that come with the ddns package
    local f = io.open("/usr/lib/ddns/services", "r")
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

-- DMZ / DynDNS / UPnP switches Only one handleQuery in a page
local qry_params = {
    DMZ_enabled = "uci.firewall.redirectsgroup.@dmzredirects.enabled",
    DMZ_destination = "uci.firewall.dmzredirect.@dmzredirect[0].dest_ip",
    ddns_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
    ddns_service_name = "uci.ddns.service.@myddns_ipv4.service_name",
    ddns_domain = "uci.ddns.service.@myddns_ipv4.domain",
    ddns_username = "uci.ddns.service.@myddns_ipv4.username",
    ddns_password = "uci.ddns.service.@myddns_ipv4.password",
    upnp_status = "uci.upnpd.config.enable_upnp",
    upnp_natpmp = "uci.upnpd.config.enable_natpmp",
    upnp_secure_mode = "uci.upnpd.config.secure_mode",
}

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSIPR = post_helper.validateStringIsPortRange
local gVP = post_helper.getValidationPassword
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)
local gAV = post_helper.getAndValidation

local qry_valid = {
    DMZ_enabled = vB,
    DMZ_destination = gVIPIL(vSIDIP, "DMZ_enabled", {"1"}),
    ddns_enabled = vB,
    ddns_service_name = gVIPIL(gVIES(ddns_supported_services), "ddns_enabled", {"1"}),
    ddns_username = gVIPIL(vNES, "ddns_enabled", {"1"}),
    ddns_password = gVP(gVIPIL(vNES, "ddns_enabled", {"1"})),
    ddns_domain = gVIPIL(vNES, "ddns_enabled", {"1"}),
    upnp_status = vB,
    upnp_natpmp = vB,
    upnp_secure_mode = vB,

}

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)
local ddns_update_info = nil
if qry_data.ddns_enabled ~= "0" then
    ddns_update_info = format("%s", ddns_status_data["ddns_status"])
end

-- In UCI
--config 'redirect'
--        option 'enabled'  '1'
--        option 'name' 'ssh'
--        option 'src' 'wan'
--        option 'proto' 'tcp'
--        option 'src_dport' '5555'
--        option 'dest_ip' '192.168.1.100'
--        option 'dest_port' '22'
--        option 'target' 'DNAT'
--        option 'dest' 'lan'

-- In Transformer
-- rpc.network.firewall.portforward.{i}.enabled
-- rpc.network.firewall.portforward.{i}.name
-- rpc.network.firewall.portforward.{i}.src
-- rpc.network.firewall.portforward.{i}.src_dport
-- rpc.network.firewall.portforward.{i}.dest_ip
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
  local wan_port_path = "uci.system.wan-service.@".. app .. ".ports."
  wan_ports[#wan_ports + 1 ] = content_helper.convertResultToObject(wan_port_path .. "@.", proxy.get(wan_port_path))
end

--Remove the ports configured in system.wan-service in allowed_portlist
local allowed_portlist = portslist
for _,wanPort in ipairs(wan_ports) do
  for i,j in pairs(allowed_portlist) do
    if wanPort[1] and (tonumber(wanPort[1].value) == tonumber(j)) then
      table_removekey(allowed_portlist,i)
    end
  end
end

-- Function to check the port are reserved or not while adding the port mapping rule.
local function allowed_ports()
  return function(ports, postdata, key)
    for _,wanPort in ipairs(wan_ports) do
      if wanPort[1] and (wanPort[1].value == ports) then
        return nil, T"Ports already Reserved"
      end
    end
    return true
  end
end

local knownapps = require("pfwd_helper")

local portrange_pattern = "^(%d+)%-(%d+)$"
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
    header = T"Destination",
    name = "destinationip",
    param = "dest_ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15" }, autocomplete=hosts_ac },
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

local pfw_valid = {
    enabled = vB,
    name = getValidateName,
    lanport = vSIPR,
    wanport = gAV(vSIPR,allowed_ports()),
    destinationip = vSIDIP,
}

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
    createMsg = T"Add new port mapping",
    newList = knownapps,
    valid = globalValid,
    sorted = "name"
}

local pfw_data, pfw_helpmsg = post_helper.handleTableQuery(pfw_columns, pfw_options, nil, pfw_defaultObject, pfw_valid)


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

%>

<% ngx.print(ui_helper.createHeader(T"WAN services", true, true)) %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/wanservices-modal.lp">
    <%
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    %>

    <fieldset class="">
      <legend><%= T"DMZ" %></legend>
      <%
        -- Switch for toggling DMZ state
        local dmzattr = {
            autocomplete = hosts_ac
        }
        ngx.print(ui_helper.createSwitch(T"Enabled", "DMZ_enabled", qry_data["DMZ_enabled"], nil, qry_helpmsg["DMZ_enabled"]),
                  ui_helper.createInputText(T"Destination", "DMZ_destination", qry_data["DMZ_destination"], dmzattr, qry_helpmsg["DMZ_destination"]))
      %>
    </fieldset>

    <fieldset>
      <legend><%= T"Port forwarding table" %></legend>
      <%
        ngx.print(ui_helper.createTable(pfw_columns, pfw_data, pfw_options, nil, pfw_helpmsg))
      %>
    </fieldset>

    <fieldset>
      <legend><%= T"UPnP" %></legend>
      <%
        local advanced = { group = { class = "advanced hide" }}
        ngx.print(
          ui_helper.createSwitch(T"UPnP Enabled", "upnp_status", qry_data["upnp_status"], advanced, qry_helpmsg["upnp_status"]),
          ui_helper.createSwitch(T"NAT-PMP Enabled", "upnp_natpmp", qry_data["upnp_natpmp"], advanced, qry_helpmsg["upnp_natpmp"]),
          ui_helper.createSwitch(T"Secure Mode Enabled", "upnp_secure_mode", qry_data["upnp_secure_mode"], advanced, qry_helpmsg["upnp_secure_mode"]),
          ui_helper.createTable(upnp_columns, upnp_data, upnp_options, nil, upnp_helpmsg)
        )
      %>
    </fieldset>

    <fieldset>
      <legend><%= T"DynDNS" %></legend>
      <%
         ngx.print(
            ui_helper.createSwitch(T"Enabled", "ddns_enabled", qry_data["ddns_enabled"], nil, qry_helpmsg["ddns_enabled"]),
            ui_helper.createInputSelect(T"Service Name", "ddns_service_name", ddns_supported_services, qry_data["ddns_service_name"], nil, qry_helpmsg["ddns_service_name"]),
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
            ui_helper.createLabel(T"Dyndns information", ddns_update_info, basic)
          )
        end
      %>
    </fieldset>
  </form>
</div>
<%= ui_helper.createFooter() %>
