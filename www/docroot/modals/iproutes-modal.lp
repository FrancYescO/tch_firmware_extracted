--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')
local format = string.format
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local validateString = post_helper.validateStringIsIP()
local uniqueKey = post_helper.getRandomKey()
local validate = post_helper.getAndValidation
local attributes = { input = { class = "span2 centered" } }

local dyn_route_columns = {
  {
    header = T"Interface",
    name = "Iface",
    param = "Iface",
    type = "text",
    readonly = true,
    attr = attributes
  },
  {
    header = T"Destination",
    name = "Destination",
    param = "Destination",
    type = "text",
    readonly = true,
    attr = attributes
  },
  {
    header = T"Mask",
    name = "Mask",
    param = "Mask",
    type = "text",
    readonly = true,
    attr = attributes
  },
  {
    header = T"Gateway",
    name = "Gateway",
    param = "Gateway",
    type = "text",
    readonly = true,
    attr = attributes
  },
  {
    header = T"Source",
    name = "Source",
    param = "Source",
    type = "text",
    readonly = true,
    attr = attributes
  },
  {
    header = T"Metric",
    name = "Metric",
    param = "Metric",
    type = "text",
    readonly = true,
    attr = attributes
  },
}

local dyn_route_options = {
  canEdit = false,
  canAdd = false,
  canDelete = false,
  tableid = "modal-IPExtras_Table_Value_DynRoute",
  basepath = "sys.class.iproutes."
}

local dyn_route_data, dyn_route_helpmsg = post_helper.handleTableQuery(dyn_route_columns, dyn_route_options)

local function split(splitValue, sep)
  local seperateValue, fields = sep or ":", {}
  local pattern = format("([^%s]+)", seperateValue)
  for field in splitValue:gmatch(pattern) do
    fields[#fields+1] = field
  end
  return fields
end

local dns_data = {}
local network_rpc_path = "rpc.network.interface."
local network_rpc_content = content_helper.getMatchedContent (network_rpc_path)

local wan_intfs = {}
for _, rpcValue in ipairs (network_rpc_content) do
  local path = split(split(format("%s", rpcValue.path), "@")[2], ".")
  if rpcValue.type == "wan" or rpcValue.type == "lan" then
    if rpcValue.dnsservers then
      local dns_column = split(rpcValue.dnsservers, ",")
      dns_data[#dns_data+1] = {path[1], dns_column[1] or "no dns server", dns_column[2] or "no dns server", dns_column[3] or "no dns server"}
    end
    if rpcValue.proto ~= "dhcpv6" and rpcValue.proto ~= "6rd" then
      wan_intfs[#wan_intfs+1] = { path[1], T(path[1]) }
    end
  end
end

local static_route_columns = {
  {
    header = T"Destination",
    name = "Destination",
    param = "target",
    type = "text",
    attr = attributes
  },
  {
    header = T"Mask",
    name = "Mask",
    param = "netmask",
    type = "text",
    attr = attributes
  },
  {
    header = T"Gateway",
    name = "Gateway",
    param = "gateway",
    type = "text",
    attr = { input = { class = "span2 centered", id = "iproutesmodal_gateway" }}
  },
  {
    header = T"Metric",
    name = "Metric",
    param = "metric",
    type = "text",
    attr = attributes
  },
  {
    header = T"Interface",
    name = "Iface",
    param = "interface",
    default = "voip",
    type = "select",
    values = wan_intfs,
    attr = { select = { class = "span2 centered" } }
  },
}

--@function to validate Duplicate Static Route
--@param object All object details coming from each rows in GUI the above table static_route_columns.
--@return #boolean, #string
local function validateDuplicateRoute(object)
  local err_count = 1
  for duplicateValue = 1, #object do
    for duplicatenum = duplicateValue+1, #object do
      for _iterator = 1, 5 do
        err_count = object[duplicateValue][_iterator] == object[duplicatenum][_iterator] and  err_count + 1 or err_count
      end
       if err_count == 5 then
         return nil, { Iface = T"Duplicate Static Route Found" }
       else
         err_count = 0
       end
    end
  end
  return true
end

local static_route_options = {
  tableid = "modal-IPExtras_Table_Value_StaticRoute",
  basepath = "uci.network.route.@.",
  createMsg = T"Add new static IPv4 route",
  objectName  = uniqueKey,
  addNamedObject = true,
  valid = validateDuplicateRoute
}

local function validateGW(ipAddress, object)
  local gatewayIP = validateString(ipAddress)
  if gatewayIP then
    return validate(post_helper.advancedIPValidation, post_helper.reservedIPValidation, post_helper.validateLXC)(ipAddress, object)
  end
  return nil, T"Invalid gateway IP."
end

local curintf = "lan"
local function validateDEST(value, object)
  local gatewayIP = validateString(value)
  local contentdata = {
    localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
    localdevmask = "uci.network.interface.@" .. curintf .. ".netmask"
  }
  content_helper.getExactContent(contentdata)
  if gatewayIP then
    return validate(validate(post_helper.staticLeaseIPValidation, post_helper.validateQTN, post_helper.validateLXC), post_helper.reservedIPValidation)(value, contentdata)
  end
  return nil, T"Invalid IP address."
end

local static_route_valid = {
  Destination = validateDEST,
  Mask = post_helper.validateIPv4Netmask,
  Gateway = validateGW,
  Metric = post_helper.getValidateNumberInRange(1, 9999),
  Interface = post_helper.getValidateInEnumSelect(wan_intfs)
}

local static_route_data, static_route_helpmsg = post_helper.handleTableQuery(static_route_columns, static_route_options, nil, nil, static_route_valid)

local dns_columns = {
  {
    header = T"Interface",
    name = "Iface",
    param = "Iface",
    type = "text",
    readonly = true,
    attr = attributes
  },
  {
    header = T"DNS Server 1",
    type = "text",
    readonly = true,
    attr = attributes
  },
  {
    header = T"DNS Server 2",
    type = "text",
    readonly = true,
    attr = attributes
  },
  {
    header = T"DNS Server 3",
    type = "text",
    readonly = true,
    attr = attributes
  },
}

local dns_options = {
  canEdit = false,
  canAdd = false,
  canDelete = false,
  tableid = "modal-IPExtras_Table_Value_Dns",
  basepath = "rpc.network.interface."
}
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Local Network", false, true))   ngx.print('\
');  
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-localnetwork.lp")
  ngx.print('\
<div class="modal-body update">\
<form class = "form-horizontal" method = "post" action = "modals/iproutes-modal.lp">\
  ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.print('\
  <fieldset>\
    <legend>');  ngx.print( T"IPv4 Dynamic Routes" ); ngx.print('</legend>\
    ');  
      ngx.print(
        ui_helper.createTable(dyn_route_columns, dyn_route_data, dyn_route_options, nil, dyn_route_helpmsg)
      )
      ngx.print('\
  </fieldset>\
\
  <fieldset>\
    <legend>');  ngx.print( T"IPv4 Static Routes Configuration" ); ngx.print('</legend>\
    ');  
      ngx.print(
        ui_helper.createTable(static_route_columns, static_route_data, static_route_options, nil, static_route_helpmsg)
      )
      ngx.print('\
  </fieldset>\
\
  <fieldset>\
    <legend>');  ngx.print( T"DNS" ); ngx.print('</legend>\
    ');  
      ngx.print(
        ui_helper.createTable(dns_columns, dns_data, dns_options, nil , nil)
      )
      ngx.print('\
  </fieldset>\
\
</form>\
</div>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 