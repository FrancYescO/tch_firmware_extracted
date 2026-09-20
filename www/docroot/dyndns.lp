--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
  ngx.print('\
\
');  
-- Localization
gettext.textdomain('webui-telstra')

local table, ipairs, require, ngx, io, format = table, ipairs, require, ngx, io, string.format
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")

local function generate_ddns_supported_services(name)
    -- open the supported services file that come with the ddns package
    local ddns_supported_services = {}
    local path = format("/etc/ddns/%s", name)
    local f = io.open(path, "r")
    if f then
      for line in f:lines() do
        local service = line:match('^%b""')
        if service then
          service = service:gsub('"','')
          local serviceline = { service , service:upper() }
          ddns_supported_services[#ddns_supported_services + 1] = serviceline
        end
      end
      f:close()
    end
    return ddns_supported_services
end

local ddnsv4_supported_services = generate_ddns_supported_services("services")
local ddnsv6_supported_services = generate_ddns_supported_services("services_ipv6")


-- DMZ / DynDNS / UPnP switches Only one handleQuery in a page
local qry_params = {
    ddns_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
    ddns_service_name = "uci.ddns.service.@myddns_ipv4.service_name",
    ddns_domain = "uci.ddns.service.@myddns_ipv4.domain",
    ddns_lookup_host = "uci.ddns.service.@myddns_ipv4.lookup_host",
    ddns_username = "uci.ddns.service.@myddns_ipv4.username",
    ddns_password = "uci.ddns.service.@myddns_ipv4.password",
}


local ddnsv6_params = {
    ddnsv6_enabled = "uci.ddns.service.@myddns_ipv6.enabled",
    ddnsv6_service_name = "uci.ddns.service.@myddns_ipv6.service_name",
    ddnsv6_domain = "uci.ddns.service.@myddns_ipv6.domain",
    ddnsv6_lookup_host = "uci.ddns.service.@myddns_ipv6.lookup_host",
    ddnsv6_username = "uci.ddns.service.@myddns_ipv6.username",
    ddnsv6_password = "uci.ddns.service.@myddns_ipv6.password",
}


-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gOrV = post_helper.getOrValidation
local gAV = post_helper.getAndValidation
local vSIDN = post_helper.validateStringIsDomainName
local vSIIP = post_helper.validateStringIsIP()
local vSIIP6 = post_helper.validateStringIsIP(6)
local gVICSPIL = post_helper.getValidationIfCheckboxSwitchPropInList
local gVIES = post_helper.getValidateInEnumSelect
local gVCS = post_helper.getValidateCheckboxSwitch()
local vNES = post_helper.validateNonEmptyString
local gVP = post_helper.getValidationPassword

local function set_lookup_host(value, object, key)
    object["ddns_lookup_host"] = object["ddns_domain"]
    return true
end

local function set_lookup_hostv6(value, object, key)
    object["ddnsv6_lookup_host"] = object["ddnsv6_domain"]
    return true
end

local qry_valid = {
    ddns_enabled = gVCS,
    ddns_service_name = gVICSPIL(gVIES(ddnsv4_supported_services), "ddns_enabled", {"1"}),
    ddns_username = gVICSPIL(vNES, "ddns_enabled", {"1"}),
    ddns_password = gVP(gVICSPIL(vNES, "ddns_enabled", {"1"})),
    ddns_domain = gAV(gOrV(vSIDN, vSIIP), gVIPIL(vNES, "ddns_enabled", {"1"})),
    ddns_lookup_host = set_lookup_host,
}

local ddnsv6_valid = {
    ddnsv6_enabled = gVCS,
    ddnsv6_service_name = gVICSPIL(gVIES(ddnsv6_supported_services), "ddnsv6_enabled", {"1"}),
    ddnsv6_username = gVICSPIL(vNES, "ddnsv6_enabled", {"1"}),
    ddnsv6_password = gVP(gVICSPIL(vNES, "ddnsv6_enabled", {"1"})),
    ddnsv6_domain = gAV(gOrV(vSIDN, vSIIP6), gVIPIL(vNES, "ddnsv6_enabled", {"1"})),
    ddnsv6_lookup_host = set_lookup_hostv6,
}

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)
local qryv6_data, qryv6_helpmsg = post_helper.handleQuery(ddnsv6_params, ddnsv6_valid)
  ngx.print('\
\
<div class="container">\
\
');  lp.include("tabs-services.lp")   ngx.print('\
\
<div class="row">\
<div class="span11">\
\
<form class="form-horizontal" method="post" action="dyndns.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
<fieldset>\
<legend>');  ngx.print( T"DynDNS IPV4" ); ngx.print('</legend>\
');  
ngx.print(
    ui_helper.createCheckboxSwitch(T"Enabled", "ddns_enabled", qry_data["ddns_enabled"], nil, qry_helpmsg["ddns_enabled"]),
    ui_helper.createInputSelect(T"Service Name", "ddns_service_name", ddnsv4_supported_services, qry_data["ddns_service_name"], nil, qry_helpmsg["ddns_service_name"]),
    ui_helper.createInputText(T"Domain", "ddns_domain", qry_data["ddns_domain"], nil, qry_helpmsg["ddns_domain"]),
    ui_helper.createInputText(T"User Name", "ddns_username", qry_data["ddns_username"], nil, qry_helpmsg["ddns_username"]),
    ui_helper.createInputPassword(T"Password", "ddns_password", qry_data["ddns_password"], nil, qry_helpmsg["ddns_password"])
)
  ngx.print('\
<legend>');  ngx.print( T"DynDNS IPV6" ); ngx.print('</legend>\
');  
ngx.print(
    ui_helper.createCheckboxSwitch(T"Enabled", "ddnsv6_enabled", qryv6_data["ddnsv6_enabled"], nil, qryv6_helpmsg["ddnsv6_enabled"]),
    ui_helper.createInputSelect(T"Service Name", "ddnsv6_service_name", ddnsv6_supported_services, qryv6_data["ddnsv6_service_name"], nil, qryv6_helpmsg["ddnsv6_service_name"]),
    ui_helper.createInputText(T"Domain", "ddnsv6_domain", qryv6_data["ddnsv6_domain"], nil, qryv6_helpmsg["ddnsv6_domain"]),
    ui_helper.createInputText(T"User Name", "ddnsv6_username", qryv6_data["ddnsv6_username"], nil, qryv6_helpmsg["ddnsv6_username"]),
    ui_helper.createInputPassword(T"Password", "ddnsv6_password", qryv6_data["ddnsv6_password"], nil, qryv6_helpmsg["ddnsv6_password"])
)
  ngx.print('\
</fieldset>\
</form>\
\
');  
lp.include("save.lp")
  ngx.print('\
\
</div>\
</div>\
</div>\
\
');  
lp.include("footer.lp")
  ngx.print('\
'); 