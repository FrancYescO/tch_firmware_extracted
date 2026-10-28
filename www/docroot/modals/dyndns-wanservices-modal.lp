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
local io, pairs, string = io, pairs, string
local ipairs,format, match = ipairs, string.format, string.match
local session = ngx.ctx.session
local role = session:getrole()
local dynDNSIPV6 = post_helper.isFeatureEnabled("DynDNSIPV6", role)
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "WANServices", "DynDNS")
local dynDNSNote = post_helper.getVariantValue(variantHelper, "dynDNSNote")

local function generate_ddns_supported_services(name)
  -- open the supported services file that comes with the ddns package
  local ddns_supported_services, valid_services = {}, {}
  local path = format("/etc/ddns/%s", name)
  local ddnsFP = io.open(path, "r")
  if ddnsFP then
    for line in ddnsFP:lines() do
      --a service in this file is  indicated as a url between quotes, we want a list with urls and name of service in capitals
      local service = line:match('^%b""')
      if service then
        service = service:gsub('"','')
        ddns_supported_services[service] = service
        valid_services[#valid_services + 1] = { service }
      end
    end
    ddnsFP:close()
  end
  return ddns_supported_services, valid_services
end

local ddns_supported_services, valid_services = generate_ddns_supported_services("services")
local ddns_ipv6_supported_services, valid_ipv6_services = generate_ddns_supported_services("services_ipv6")

local ddns_path = proxy.get("uci.ddns.service.@myddns_ipv4.")
local ddns_ipv6_path = proxy.get("uci.ddns.service.@myddns_ipv6.")

local ddns_status_data = {
  ddns_status = "rpc.ddns.status"
}
content_helper.getExactContent(ddns_status_data)

local ddns_params = {
  ddns_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
  ddns_service_name = "uci.ddns.service.@myddns_ipv4.service_name",
  ddns_domain = "uci.ddns.service.@myddns_ipv4.domain",
  ddns_username = "uci.ddns.service.@myddns_ipv4.username",
  ddns_password = "uci.ddns.service.@myddns_ipv4.password",
  ddns_usehttps = "uci.ddns.service.@myddns_ipv4.use_https",
  ddnsv6_enabled = "uci.ddns.service.@myddns_ipv6.enabled",
  ddnsv6_service_name = "uci.ddns.service.@myddns_ipv6.service_name",
  ddnsv6_domain = "uci.ddns.service.@myddns_ipv6.domain",
  ddnsv6_username = "uci.ddns.service.@myddns_ipv6.username",
  ddnsv6_password = "uci.ddns.service.@myddns_ipv6.password",
  ddnsv6_usehttps = "uci.ddns.service.@myddns_ipv6.use_https",
}

-- Shortcuts to validation helpers to make lines shorter
local validateEnum = post_helper.getValidateInEnumSelect
local validateBoolean = post_helper.validateBoolean
local andValidation = post_helper.getAndValidation
local orValidation = post_helper.getOrValidation
local validateDomainName = post_helper.validateStringIsDomainName
local validateIP = post_helper.validateStringIsIP()
local optionalValidation = post_helper.getOptionalValidation
local validateStringLength = post_helper.getValidateStringLengthInRange(1, 255)
local validatePassword = post_helper.getValidationPassword

local function validateDomain(value)
  if validateIP(value) then
    return andValidation(post_helper.reservedIPValidation, post_helper.validateLXC)(value)
  end
  return validateDomainName(value)
end

local ddns_valid = {
  ddns_enabled = validateBoolean,
  ddns_service_name = andValidation(orValidation(validateDomainName, validateIP), validateEnum(valid_services)),
  ddns_username = optionalValidation(andValidation(validateStringLength, post_helper.isSpaceInString)),
  ddns_password = validatePassword(optionalValidation(post_helper.isSpaceInString)),
  ddns_domain = optionalValidation(validateDomain),
  ddns_usehttps = validateBoolean,
  ddnsv6_enabled = validateBoolean,
  ddnsv6_service_name = andValidation(orValidation(validateDomainName, validateIP), validateEnum(valid_services)),
  ddnsv6_username = optionalValidation(andValidation(validateStringLength, post_helper.isSpaceInString)),
  ddnsv6_password = validatePassword(optionalValidation(post_helper.isSpaceInString)),
  ddnsv6_domain = optionalValidation(validateDomain),
  ddnsv6_usehttps = validateBoolean
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

local ddns_data, ddns_helpmsg, ddns_status, ddns_update_info, action

if ngx.var.request_method == "POST" then
  action = ngx.req.get_post_args().action
end

ddns_data, ddns_helpmsg = post_helper.handleQuery(ddns_params, ddns_valid)
local isValidationError = false
if ddns_helpmsg and next(ddns_helpmsg) then
 isValidationError = true
end

local new_host = {}
local count = 0
for k,v in pairs(ddns_supported_services) do
  if v == ddns_data.ddns_service_name then
    count = 1
    new_host[#new_host+1] = {v,k}
  else
    new_host[#new_host+1] = {v,k}
  end
end

if ngx.var.request_method == "POST" then
  if not next(ddns_helpmsg) then
    local setTable = {}
    setTable["uci.ddns.service.@myddns_ipv4.cacert"] = "IGNORE"
    setTable["uci.ddns.service.@myddns_ipv4.lookup_host"] = ddns_data.ddns_domain
    setTable["uci.ddns.service.@myddns_ipv6.cacert"] = "IGNORE"
    setTable["uci.ddns.service.@myddns_ipv6.lookup_host"] = ddns_data.ddnsv6_domain
    proxy.set(setTable)
    proxy.apply()
  end
end

local function get_ddns_status(service_name, ddns_enabled)
  local ddns_status = "error"
  local status = ddns_status_data.ddns_status
  local ddns_update_info = "No error received from server"
  local service_status

  if status then
    for service_value in string.gmatch(status, '([^%]]+)') do
      service_status = match(service_value, service_name .. "%[(.+)")
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

if ddns_path then
  ddns_status, ddns_update_info = get_ddns_status("myddns_ipv4", ddns_data.ddns_enabled)
end

local ddns_ipv6_status, ddns_ipv6_update_info
if ddns_ipv6_path then
  ddns_ipv6_status, ddns_ipv6_update_info = get_ddns_status("myddns_ipv6", ddns_data.ddnsv6_enabled)
end

-- DNS rules
local policy_select = {{"any", "any"}}
local outpolicy_select = {{"copy", "copy"}, {"default", "default"}}

local policy_pn = proxy.getPN("uci.mwan.policy.", true)
if policy_pn then
  for _, v in ipairs(policy_pn) do
    local path = v.path
    local policy_name = match(path, "@([^@%.]-)%.")
    if policy_name then
      policy_select[#policy_select + 1] = {policy_name, policy_name}
      outpolicy_select[#outpolicy_select + 1] = {policy_name, policy_name}
    end
  end
end

local intfs_select = {{"default", "default"}}

local intfs_pn = proxy.getPN("uci.network.interface.", true)
if intfs_pn then
  for _, v in ipairs(intfs_pn) do
    local path = v.path
    local intf_name = match(path, "@([^@%.]-)%.")
    if intf_name and intf_name ~= "loopback" and intf_name ~= "lan" then
      intfs_select[#intfs_select + 1] = {intf_name, intf_name}
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
    attr = { switch = { ["data-placement"] = "right" } }
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
  v[1] = (v[1] and v[1] == "") and "1" or v[1]
  v[4] = (v[4] and v[4] == "") and "any" or v[4]
  v[5] = (v[5] and v[5] == "") and "copy" or v[5]
end

  ngx.print('\
\
');  
local function ddnsNote()
  if dynDNSNote then
    ngx.print(ui_helper.createLabel(T"", T"Note: HTTPS mode will enable encryption but not certificate-based authentication", { span = {class = "span12"},}))
  else
    ngx.print(ui_helper.createLabel(T"", T"Note: HTTPS mode will enable encryption but not certificate-based authentication of DynDNS service", { span = {class = "span12"},}))
  end
end
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"WAN services", true, true))  ngx.print('\
\
<div class="modal-body update" style="overflow-x:hidden;">\
  <form class="form-horizontal" method="post" action="modals/dyndns-wanservices-modal.lp">\
    ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
       lp.setpath("/www/snippets/")
       lp.include("tabs-wanservices.lp")   ngx.print('\
    ');  if post_helper.isFeatureEnabled("wanServicesDnsRule", role) then   ngx.print('\
    <fieldset >\
      <legend>');  ngx.print( T"DNS rules" ); ngx.print('</legend>\
      ');  ngx.print(ui_helper.createTable(dnsrule_columns, dnsrule_data, dnsrule_options, nil, dnsrule_helpmsg))   ngx.print('\
    </fieldset>\
    ');  end   ngx.print('\
    <fieldset>\
      ');  if dynDNSIPV6 then   ngx.print('\
        <legend>');  ngx.print( T"DynDNS IPV4" ); ngx.print('</legend>\
      ');  else  ngx.print('\
        <legend>');  ngx.print( T"DynDNS" ); ngx.print('</legend>\
      ');  end  ngx.print('\
      ');  ngx.print(
          ui_helper.createLight(T"Status", nil, ddns_state_map[ddns_status], { light = { class = ddns_light_map[ddns_status] } }),
          ui_helper.createSwitch(T"Enabled", "ddns_enabled", ddns_data["ddns_enabled"], nil, ddns_helpmsg["ddns_enabled"]),
          ui_helper.createInputSelect(T"Service Name", "ddns_service_name", new_host, ddns_data.ddns_service_name, nil, ddns_helpmsg.ddns_service_name),
          ui_helper.createSwitch(T"HTTPS", "ddns_usehttps", ddns_data["ddns_usehttps"], nil, ddns_helpmsg["ddns_usehttps"])
        )   ngx.print('\
      ');  ddnsNote()   ngx.print('\
      ');  ngx.print(
          ui_helper.createInputText(T"Domain", "ddns_domain", ddns_data["ddns_domain"], nil, ddns_helpmsg["ddns_domain"]),
          ui_helper.createInputText(T"User Name", "ddns_username", ddns_data["ddns_username"], nil, ddns_helpmsg["ddns_username"]),
          ui_helper.createInputPassword(T"Password", "ddns_password", ddns_data["ddns_password"], nil, ddns_helpmsg["ddns_password"])
        )
        if ddns_data["ddns_enabled"] == "1" then
          local basic = {
            span = {
            class = "span12"
            },
          }
          ngx.print(
            ui_helper.createLabel(T"DynDNS Information", ddns_update_info, basic)
          )
        end   ngx.print('\
    </fieldset>\
    <br>\
    <div class=\'');  ngx.print( dynDNSIPV6 and "show" or "hide"); ngx.print('\'>\
      <fieldset>\
        <legend>');  ngx.print( T"DynDNS IPV6" ); ngx.print('</legend>\
        ');  ngx.print(
            ui_helper.createLight(T"Status", nil, ddns_state_map[ddns_ipv6_status], { light = { class = ddns_light_map[ddns_ipv6_status] } }),
            ui_helper.createSwitch(T"Enabled", "ddnsv6_enabled", ddns_data["ddnsv6_enabled"], nil, ddns_helpmsg["ddnsv6_enabled"]),
            ui_helper.createInputSelect(T"Service Name", "ddnsv6_service_name", new_host, ddns_data.ddnsv6_service_name, nil, ddns_helpmsg.ddnsv6_service_name),
            ui_helper.createSwitch(T"HTTPS", "ddnsv6_usehttps", ddns_data["ddnsv6_usehttps"], nil, ddns_helpmsg["ddnsv6_usehttps"])
          )   ngx.print('\
        ');  ddnsNote()   ngx.print('\
        ');  ngx.print(
            ui_helper.createInputText(T"Domain", "ddnsv6_domain", ddns_data["ddnsv6_domain"], nil, ddns_helpmsg["ddnsv6_domain"]),
            ui_helper.createInputText(T"User Name", "ddnsv6_username", ddns_data["ddnsv6_username"], nil, ddns_helpmsg["ddnsv6_username"]),
            ui_helper.createInputPassword(T"Password", "ddnsv6_password", ddns_data["ddnsv6_password"], nil, ddns_helpmsg["ddnsv6_password"])
          )
          if ddns_data["ddnsv6_enabled"] == "1" then
            local basic = {
              span = {
              class = "span12"
              },
            }
            ngx.print(
              ui_helper.createLabel(T"DynDNS Information", ddns_ipv6_update_info, basic)
            )
          end   ngx.print('\
      </fieldset>\
    </div>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
<script src="/js/wanservices.js"></script>\
'); 