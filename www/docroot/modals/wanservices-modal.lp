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
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()
local io, pairs, string = io, pairs, string
local table, ipairs, tonumber, format, match = table, ipairs, tonumber, string.format, string.match

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
    DMZ_enable = "rpc.network.firewall.dmz.enable",
    DMZ_destinationip = "rpc.network.firewall.dmz.redirect.dest_ip",
    ddns_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
    ddns_service_name = "uci.ddns.service.@myddns_ipv4.service_name",
    ddns_domain = "uci.ddns.service.@myddns_ipv4.domain",
    ddns_lookup_host = "uci.ddns.service.@myddns_ipv4.lookup_host",
    ddns_username = "uci.ddns.service.@myddns_ipv4.username",
    ddns_password = "uci.ddns.service.@myddns_ipv4.password",
    upnp_status = "uci.upnpd.config.enable_upnp",
    upnp_natpmp = "uci.upnpd.config.enable_natpmp",
    upnp_secure_mode = "uci.upnpd.config.secure_mode",
}

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
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
local gAV = post_helper.getAndValidation
local gOrV = post_helper.getOrValidation
local vSIDN = post_helper.validateStringIsDomainName
local vSIIP = post_helper.validateStringIsIP

local function validate_dmz_dest(value, object, key)
  if value == "" and object["DMZ_enable"] ~= "1" and type(object["DMZ_enable"]) ~= "table" then
    -- Empty dmz_destination field is allowed if and only if DMZ_enable is not enabled
    return true
  end
  return vSIDIP(value, object, key)
end

local function set_lookup_host(value, object, key)
    object["ddns_lookup_host"] = object["ddns_domain"]
    return true
end

local qry_valid = {
    DMZ_enable = gVCS,
    DMZ_destinationip = validate_dmz_dest,
    ddns_enabled = gVCS,
    ddns_service_name = gVICSPIL(gVIES(ddns_supported_services), "ddns_enabled", {"1"}),
    ddns_username = gVICSPIL(vNES, "ddns_enabled", {"1"}),
    ddns_password = gVP(gVICSPIL(vNES, "ddns_enabled", {"1"})),
    ddns_domain = gAV(gOrV(vSIDN, vSIIP), gVIPIL(vNES, "ddns_enabled", {"1"})),
    ddns_lookup_host = set_lookup_host,
    upnp_status = gVCS,
    upnp_natpmp = gVCS,
    upnp_secure_mode = gVCS,
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

local wol = io.open("/lib/functions/firewall-wol.sh", "r") and proxy.get("uci.wol.config.")
if wol then
  qry_params.WOL_enabled = "uci.wol.config.enabled"
  qry_params.WOL_port = "uci.wol.config.src_dport"
  qry_valid.WOL_enabled = gVCS
  qry_valid.WOL_port = vSIP
end

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)

local action
if ngx.var.request_method == "POST" then
  action = ngx.req.get_post_args().action
  local content = ngx.req.get_post_args()

  if content.action == "TABLE-DELETE" and content.tableid == "portforwarding" then
    del_pfw_index = tonumber(content.index)
  end
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

    ddns_update_info = format("%s", ddns_status_data.ddns_status)
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

local function getValidateLanPort(value, object, key)
    if value == "" then
       local validated, msg = vSIPR(object["wanport"], object, key)
       if validated then
          return true
       end
    end
    return vSIPR(value, object, key)
end

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
    enabled = gVCS,
    name = getValidateName,
    lanport = getValidateLanPort,
    wanport = gAV(vSIPR,allowed_ports()),
    destinationip = vSIDIP,
    protocol = gVIES(protocolList),
}

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
    createMsg = T"Add new port mapping",
    newList = knownapps,
    valid = globalValid,
    sorted = "name",
    onModify = update_firewall_helper,
    onAdd = update_firewall_helper,
    onDelete = onDelete,
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
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"WAN services", true, false, nil, help_link) ); ngx.print('\
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
        ngx.print(ui_helper.createCheckboxSwitch(T"Enabled", "DMZ_enable", qry_data["DMZ_enable"], nil, qry_helpmsg["DMZ_enable"]),
                  ui_helper.createInputText(T"Destination IP", "DMZ_destinationip", qry_data["DMZ_destinationip"], dmzipattr, qry_helpmsg["DMZ_destinationip"]),
                  ui_helper.createLabel(T"Destination MAC", DMZ_destinationmac[1]))
        ngx.print('\
    </fieldset>\
\
    <fieldset>\
      <legend>');  ngx.print( T"Port forwarding table" ); ngx.print('</legend>\
      ');  
        ngx.print(ui_helper.createTable(pfw_columns, pfw_data, pfw_options, nil, pfw_helpmsg))
        ngx.print('\
    </fieldset>\
\
    <fieldset>\
      <legend>');  ngx.print( T"UPnP" ); ngx.print('</legend>\
      ');  
        local advanced = { group = { class = "advanced hide" }}
        ngx.print(
          ui_helper.createCheckboxSwitch(T"UPnP Enabled", "upnp_status", qry_data["upnp_status"], advanced, qry_helpmsg["upnp_status"]),
          ui_helper.createCheckboxSwitch(T"NAT-PMP Enabled", "upnp_natpmp", qry_data["upnp_natpmp"], advanced, qry_helpmsg["upnp_natpmp"]),
          ui_helper.createCheckboxSwitch(T"Secure Mode Enabled", "upnp_secure_mode", qry_data["upnp_secure_mode"], advanced, qry_helpmsg["upnp_secure_mode"]),
          ui_helper.createTable(upnp_columns, upnp_data, upnp_options, nil, upnp_helpmsg)
        )
        ngx.print('\
    </fieldset>\
\
    <fieldset class="advanced hide">\
      <legend>');  ngx.print( T"DynDNS" ); ngx.print('</legend>\
      ');  
         ngx.print(
            ui_helper.createLight(T"Status", nil, ddns_state_map[ddns_status], { light = { class = ddns_light_map[ddns_status] } }),
            ui_helper.createCheckboxSwitch(T"Enabled", "ddns_enabled", qry_data["ddns_enabled"], nil, qry_helpmsg["ddns_enabled"]),
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
          ngx.print(ui_helper.createCheckboxSwitch(T"Enabled", "WOL_enabled", qry_data["WOL_enabled"], nil, qry_helpmsg["WOL_enabled"]),
                    ui_helper.createInputText(T"WAN port", "WOL_port", qry_data["WOL_port"], nil, qry_helpmsg["WOL_port"]))
          ngx.print('\
      </fieldset>\
    ');  end  ngx.print('\
\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 