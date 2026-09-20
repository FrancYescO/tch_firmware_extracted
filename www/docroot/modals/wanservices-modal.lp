<%
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local portslist = require("portslist_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local table, ipairs = table, ipairs

local ddns_supported_services = {}

local function generate_ddns_supported_services()
-- open the supported services file that come with the ddns package
    local f = io.open("/usr/lib/ddns/services", "r")
    if f then
        for line in f:lines() do
--a service in this file is  indicated as a url between quotes, we want a list with urls and name of service in capitals
           local service = line:match('^%b""')
           if service then
          service = service:gsub('"','')
              local serviceline = { service , service:upper():match('[%a%w]*%.'):gsub('%.','') }
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

-- DMZ / DynDNS / UPnP switches Only one handleQuery in a page
local qry_params = {
    DMZ_enabled = "uci.firewall.redirectsgroup.@dmzredirects.enabled",
    DMZ_destination = "uci.firewall.dmzredirect.1.dest_ip",
    ddns_enabled = "uci.ddns.service.@myddns.enabled",
    ddns_service_name = "uci.ddns.service.@myddns.service_name",
    ddns_domain = "uci.ddns.service.@myddns.domain",
    ddns_username = "uci.ddns.service.@myddns.username",
    ddns_password = "uci.ddns.service.@myddns.password",
    upnp_status = "uci.upnpd.config.enable_upnp",
    upnp_natpmp = "uci.upnpd.config.enable_natpmp",
    upnp_secure_mode = "uci.upnpd.config.secure_mode",
}

-- Shortcuts to validation helpers to make lines shorter
local gVICSPIL = post_helper.getValidationIfCheckboxSwitchPropInList
local gVIES = post_helper.getValidateInEnumSelect
local gVCS = post_helper.getValidateCheckboxSwitch()
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSIP = post_helper.validateStringIsPort
local vSIPR = post_helper.validateStringIsPortRange
local gVP = post_helper.getValidationPassword
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local vSIDIP = gVSIDIP(ipdetails.gw, ipdetails.netmask)

local function validate_dmz_dest(value, object, key)
  if value == "" and object["DMZ_enabled"] ~= "1" and type(object["DMZ_enabled"]) ~= "table" then
    -- Empty dmz_destination field is allowed if and only if DMZ_enabled is not enabled
    return true
  end
  return vSIDIP(value, object, key)
end

local qry_valid = {
    DMZ_enabled = gVCS,
    DMZ_destination = validate_dmz_dest,
    ddns_enabled = gVCS,
    ddns_service_name = gVICSPIL(gVIES(ddns_supported_services), "ddns_enabled", {"1"}),
    ddns_username = gVICSPIL(vNES, "ddns_enabled", {"1"}),
    ddns_password = gVP(gVICSPIL(vNES, "ddns_enabled", {"1"})),
    ddns_domain = gVICSPIL(vNES, "ddns_enabled", {"1"}),
    upnp_status = gVCS,
    upnp_natpmp = gVCS,
    upnp_secure_mode = gVCS,

}

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)

-- In UCI
--config 'redirect'
--        option 'name' 'ssh'
--        option 'src' 'wan'
--        option 'proto' 'tcp'
--        option 'src_dport' '5555'
--        option 'dest_ip' '192.168.1.100'
--        option 'dest_port' '22'
--        option 'target' 'DNAT'
--        option 'dest' 'lan'

-- In Transformer
-- uci.firewall.redirect.{i}.name
-- uci.firewall.redirect.{i}.src
-- uci.firewall.redirect.{i}.src_dport
-- uci.firewall.redirect.{i}.dest_ip
-- uci.firewall.redirect.{i}.dest_port
-- uci.firewall.redirect.{i}.target
-- uci.firewall.redirect.{i}.dest
-- uci.firewall.redirect.{i}.proto.@1.value

-- Templates for pre-defined rules
local knownapps = require("pfwd_helper")

local portrange_pattern = "^(%d+)%-(%d+)$"
function compare_startport(a,b)
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
    type = "checkboxswitch",
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
    attr = { input = { class="span1", maxlength="11" }, autocomplete=portslist },
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
    attr = { input = { class="span2", maxlength="15"}, autocomplete=hosts_ac },
  },
}

local pfw_attributes = {
}

local function getValidateLanPort(value, object,key)
    if value == "" then
       local validated, msg = vSIPR(object["wanport"])
       if validated then
          object[key] = object["wanport"]
          return true
       end
    end
    return vSIPR(value)
end

local pfw_valid = {
    enabled = gVCS,
    name = vNES,
    lanport = getValidateLanPort,
    wanport = vSIPR,
    destinationip = vSIDIP,
}

-- Warning, this uses transformer paths. So use correct naming
local pfw_defaultObject = {
    src = "wan",
    dest = "lan",
    family = "ipv4",
    target = "DNAT",
}

local pfw_filter = nil

local pfw_options = {
    tableid = "portforwarding",
    basepath = "uci.firewall.userredirect.",
    createMsg = T"Add new port mapping",
    newList = knownapps,
    valid = globalValid,
}

local pfw_data, pfw_helpmsg = post_helper.handleTableQuery(pfw_columns, pfw_options, pfw_filter, pfw_defaultObject, pfw_valid)

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
    header = T"Destination IP",
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

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
%>

<% =ui_helper.createHeader(T"WAN services", true, false, nil, help_link) %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/wanservices-modal.lp">
    <%
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    %>

    <fieldset class="advanced hide">
      <legend><%= T"DMZ" %></legend>
      <%
        -- Switch for toggling DMZ state
        local dmzattr = {
            autocomplete = hosts_ac
        }
        ngx.print(ui_helper.createCheckboxSwitch(T"Enabled", "DMZ_enabled", qry_data["DMZ_enabled"], nil, qry_helpmsg["DMZ_enabled"]),
                  ui_helper.createInputText(T"Destination IP", "DMZ_destination", qry_data["DMZ_destination"], dmzattr, qry_helpmsg["DMZ_destination"]))
      %>
    </fieldset>

    <fieldset>
      <legend><%= T"Port forwarding table" %></legend>
      <%
        ngx.print(ui_helper.createTable(pfw_columns, pfw_data, pfw_options, pfw_attributes, pfw_helpmsg))
      %>
    </fieldset>

    <fieldset>
      <legend><%= T"UPnP" %></legend>
      <%
        local advanced = { group = { class = "advanced hide" }}
        ngx.print(
          ui_helper.createCheckboxSwitch(T"UPnP Enabled", "upnp_status", qry_data["upnp_status"], advanced, qry_helpmsg["upnp_status"]),
          ui_helper.createCheckboxSwitch(T"NAT-PMP Enabled", "upnp_natpmp", qry_data["upnp_natpmp"], advanced, qry_helpmsg["upnp_natpmp"]),
          ui_helper.createCheckboxSwitch(T"Secure Mode Enabled", "upnp_secure_mode", qry_data["upnp_secure_mode"], advanced, qry_helpmsg["upnp_secure_mode"]),
          ui_helper.createTable(upnp_columns, upnp_data, upnp_options, upnp_attributes, upnp_helpmsg)
        )
      %>
    </fieldset>

    <fieldset class="advanced hide">
      <legend><%= T"DynDNS" %></legend>
      <%
        ngx.print(
          ui_helper.createCheckboxSwitch(T"Enabled", "ddns_enabled", qry_data["ddns_enabled"], nil, qry_helpmsg["ddns_enabled"]),
          ui_helper.createInputSelect(T"Service Name", "ddns_service_name", ddns_supported_services, qry_data["ddns_service_name"], nil, qry_helpmsg["ddns_service_name"]),
          ui_helper.createInputText(T"Domain", "ddns_domain", qry_data["ddns_domain"], nil, qry_helpmsg["ddns_domain"]),
          ui_helper.createInputText(T"User Name", "ddns_username", qry_data["ddns_username"], nil, qry_helpmsg["ddns_username"]),
          ui_helper.createInputPassword(T"Password", "ddns_password", qry_data["ddns_password"], nil, qry_helpmsg["ddns_password"])
        )
      %>
    </fieldset>


  </form>
</div>

<%= ui_helper.createFooter() %>
