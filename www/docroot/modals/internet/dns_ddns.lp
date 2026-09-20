--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local ngx = ngx
local proxy = require("datamodel")
local string = string
local match, format = string.match, string.format
local post_helper = require("web.post_helper")
local validateIfPropertyExist = post_helper.getValidationIfPropInList
local validateStringLength = post_helper.getValidateStringLengthInRange(1, 255)
local content_helper = require("web.content_helper")
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")
local splitIP = vdf_helper.split_IP_into_Octets
local dataInterface = vdf_helper.getDataInterface
dataInterface = dataInterface()

local vodafone = {
  variant = "uci.env.var.vodafone_variant",
}
content_helper.getExactContent(vodafone)
local gatewayName = vdf_helper.productName()

local ddnsData = {
  password = "uci.ddns.service.@myddns_ipv4.password",
  userName = "uci.ddns.service.@myddns_ipv4.username",
  Domain = "uci.ddns.service.@myddns_ipv4.domain",
  Service = "uci.ddns.service.@myddns_ipv4.service_name",
  gatewayIP = "uci.network.interface.@lan.ipaddr",
}
content_helper.getExactContent(ddnsData)

-- Filtering secureDNS details based on name "secure_dns"
local secureDns =  content_helper.getMatchedContent("uci.firewall.redirect.", { name = "secure_dns"} )

-- DNS Information from all interfaces
local primaryDNSValue, secondaryDNSValue

for i=1, #dataInterface do
  local path = format("uci.network.interface.@%s.dns.", dataInterface[i])
  local dnsVox = content_helper.convertResultToObject(path, proxy.get(path)) or {}
  if next(dnsVox) then
    primaryDNSValue = dnsVox[1].value
    if #dnsVox >=2 then
      secondaryDNSValue = dnsVox[2].value
    end
  end
end

local serviceProviders = {
  {"dtdns.com","dtdns.com"},
  {"dyndns.org","dyndns.org"},
  {"no-ip.com","no-ip.com"},
  {"changeip.com","changeip.com"},
  {"dyn.com","dyn.com"},
  {"easydns.com","easydns.com"},
  {"zoneedit.com","zoneedit.com"},
}

local ddnsParams = {
  ddnsStatus = "uci.ddns.service.@myddns_ipv4.enabled",
  ddnsService = "uci.ddns.service.@myddns_ipv4.service_name",
  ddnsDomain = "uci.ddns.service.@myddns_ipv4.domain",
  ddnsUsrname = "uci.ddns.service.@myddns_ipv4.username",
}

local ddnsParamValid = {
  ddnsStatus = post_helper.validateBoolean,
  ddnsService = post_helper.getValidateInEnumSelect(serviceProviders),
  ddnsDomain = post_helper.getOptionalValidation(post_helper.validateStringIsDomainName),
  ddnsUsrname = post_helper.getOptionalValidation(validateStringLength),
}

local ddns, errormsg = post_helper.handleQuery(ddnsParams, ddnsParamValid)
local resetdns = {
  reset_secure_dns = "uci.uci-defaults.dns.secure_dns",
  reset_dynamic_dns = "uci.uci-defaults.dns.dynamic_dns",
  reset_provider = "uci.uci-defaults.dns.provider",
  reset_domain_name = "uci.uci-defaults.dns.domain_name",
  reset_account = "uci.uci-defaults.dns.account",
  reset_password = "uci.uci-defaults.dns.password"
}
content_helper.getExactContent(resetdns)

local function validateLocalDevIP(value, object, key)
  local isIP, isIPerrmsg = post_helper.validateStringIsIP(value, object, key)
  if isIP then
    object["localdevmask"] = proxy.get("uci.network.interface.@lan.netmask")[1].value
    local dns, dnserrmsg = post_helper.DNSIPValidation(value, object, key)
    if not dns then
      return nil, dnserrmsg
    end
    local res, reserrmsg = post_helper.reservedIPValidation(value, object, key)
    if not res then
      return nil, reserrmsg
    end
  else
    return nil, isIPerrmsg
  end
  return true
end

local function dnsUpdate(postArgs)
  local DNSContent = {
    dns1 = postArgs.primarydns,
    dns2 = postArgs.secondarydns
  }
  local DNSValidation = {
    dns1 = validateLocalDevIP,
    dns2 = post_helper.getOptionalValidation(post_helper.validateStringIsIP)
  }
  local con , err = content_helper.validateObject(DNSContent, DNSValidation)
  if not next(err)  then
    return true
  end
  return nil, err
end

local  function onPost()
  local success = true
  local flag = false
  if ngx.req.get_post_args().ddnsStatus == "1" then
    if not (ddnsData["password"] ~= "" and ngx.req.get_post_args().ddnsPswrd == "") or (ddnsData["userName"] ~=ngx.req.get_post_args().ddnsUsrname) then
      success = validateStringLength(ngx.req.get_post_args().ddnsPswrd)
    end
  end
  local postArgs = ngx.req.get_post_args()
  local dnsSuccess = dnsUpdate(postArgs)
  local setTable = {}
  if not next(errormsg) and success and ngx.var.content_type and match(ngx.var.content_type, "application/x%-www%-form%-urlencoded") then
    -- set operation for secureDNS enable option and Destination IPAddress.
    if ngx.req.get_post_args().securedns then
      local index = match(secureDns[1].path, ".(@%S+).")
      setTable[format("uci.firewall.redirect.%s.enabled",index)] = ngx.req.get_post_args().securedns
      setTable[format("uci.firewall.redirect.%s.dest_ip",index)] = ddnsData.gatewayIP
    end
    if ngx.req.get_post_args().manualdns == "1" then
      if dnsSuccess then
        for i=1, #dataInterface do
          proxy.del(format("uci.network.interface.@%s.dns.",dataInterface[i]))
          proxy.get(format("uci.network.interface.@%s.dns.",dataInterface[i]))
          local index = proxy.add(format("uci.network.interface.@%s.dns.",dataInterface[i]))
          setTable[format("uci.network.interface.@%s.dns.@%s.value",dataInterface[i],index)] = ngx.req.get_post_args().primarydns
          if ngx.req.get_post_args().secondarydns ~= "" then
            local index = proxy.add(format("uci.network.interface.@%s.dns.",dataInterface[i]))
            setTable[format("uci.network.interface.@%s.dns.@%s.value",dataInterface[i],index)] = ngx.req.get_post_args().secondarydns
          end
        end
        proxy.set("uci.network.interface.@wan.peerdns", "0")
      else
        return nil, errormsg
      end
    else
      for i=1, #dataInterface do
        proxy.del(format("uci.network.interface.@%s.dns.",dataInterface[i]))
      end
      proxy.set("uci.network.interface.@wan.peerdns", "1")
    end
    if ngx.req.get_post_args().ddnsStatus == "1" then
      local passwd = ngx.req.get_post_args().ddnsPswrd == "" and ddnsData["password"] or ngx.req.get_post_args().ddnsPswrd
      setTable["uci.ddns.service.@myddns_ipv4.password"] = passwd
      setTable["uci.ddns.service.@myddns_ipv4.lookup_host"] = ngx.req.get_post_args().ddnsDomain
    end
    proxy.set(setTable)
    proxy.apply()
    return true
  else
    return nil
  end
end
vdf_helper.handlePOST(onPost, nil, "true", "json")

local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
<script src="js/global-min.js"></script>\
<form id="dns-ddns-form" class="form-horizontal" method="post" action="modals/internet/dns_ddns.lp">\
  <div class="row no-margin-right">\
    <div class="col-xs-12 col-md-8 col-sm-8">\
      <h1>\
        <span>');  ngx.print(T"DNS"); ngx.print('</span>\
      </h1>\
    </div>\
  </div>\
  <h2>\
  <span>');  ngx.print(T"The DNS configuration is done automatically when you connect to the network. Alternatively you can manually configure your   own DNS settings on your devices."); ngx.print('\
    </span>\
  </h2>\
  ');  if vodafone.variant == "VF-UK" then   ngx.print('\
  <div class="padding-bottom-wrap">\
    <div class="h3-content no-padding-bottom mobile-no-table vdf-table">\
      <div class="vdf-row mobile-no-floating font-bold">\
        <div class="left">\
          <span>');  ngx.print(T"DNS configuration"); ngx.print('</span>\
        </div>\
        <div class="right">\
          <input class="radio" checked = "checked" name="dns-config" id="internet-radio-auto" value="1" type="radio">\
          <label for="internet-radio-auto"></label>\
          <span>');  ngx.print( T"Automatically"); ngx.print('</span>      </div>\
        <div class="right">\
          <input class="radio" name="dns-config" id="internet-radio-manual" value="2" type="radio">\
          <label for="internet-radio-manual"></label>\
          <span>');  ngx.print(T"Manually"); ngx.print('</span>      </div>\
      </div>\
    </div>\
    <div class="dnsContent level-3">\
      ');  
        local row = {
          {
            label = T"Domain Name Server (DNS) Address",
            element = ui_helper.createIPAddressFields("dns-txt-pridns", "primarydns", primaryDNSValue),
            labelClass = "font-normal"
          },
          {
            label = T"Secondary DNS Address (optional)",
            element = ui_helper.createIPAddressFields("dns-txt-secdns", "secondarydns", secondaryDNSValue),
            labelClass = "font-normal"
          }
        }
        ngx.print(ui_helper.createTable(row, "", "h3-content no-padding-bottom mobile-no-table vdf-table"))
        ngx.print('\
   </div>\
   ');  elseif vodafone.variant ~= "VF-UK" then   ngx.print('\
    <div class="h3-content vdf-table h3-content-mobile">\
      ');  
        local row = {
          label = "Secure DNS",
        element = ui_helper.createButton({
          class= (secureDns[1].enabled ~= "0") and "button toggle-content-button pull-right button-on" or "button toggle-content-button pull-right button-off",
          id="ddns-btn-sdns"
          })
        }
        ngx.print(ui_helper.createRow(row))
        ngx.print('\
      <div class="row padding-top-bottom-20 no-margin-right" id="ddns-div-sdns">\
        <div class="col-xs-12 col-md-12 col-sm-12 dmz-message-info">\
          <div class="message-info">\
        <span>');  ngx.print(T"Keep Secure DNS setting to ON in order to prevent malware to infect your devices and direct your Internet traffic       tmalicious websites. You can turn it OFF if you wish to manually configure the DNS on your devices."); ngx.print('\
            </span>\
          </div>\
        </div>\
      </div>\
    </div>\
  ');  end   ngx.print('\
\
  <h1 class="padding-top-wrap">');  ngx.print(T"DDNS (Dynamic DNS)"); ngx.print('</h1>\
  <h2>');  ngx.print((T"DDNS allows you to access your " .. gatewayName .. T"  from the internet using a domain name instead of an IP Address. You'll need an account with a DDNS service provider.")); ngx.print('</h2>\
  <div class="padding-bottom-wrap">\
    <div class="h3-content vdf-table no-padding-bottom font-bold">\
      ');  
        row = {
          label = "Dynamic DNS",
          element = ui_helper.createButton({
            id="dns-ddns-btn-ddns_enable",
            class=ddns.ddnsStatus == "1" and "button button-on" or "button button-off",
            name="ddnsStatus"
            })
        }
        ngx.print(ui_helper.createRow(row))
        ngx.print('\
    </div>\
    <div class="ddnsContent ddns_account_details level-3 shadowProblem" ');  if ddns.ddnsStatus ~= "1" then  ngx.print('style="display:none"');  end  ngx.print(' >\
      ');  
        row = {
          {
            label = "Provider",
            element = ui_helper.createDropDown({
              class="dropdown",
              id="dns-ddns-select-service",
              name="ddnsService"
              }, serviceProviders),
            rowClass = "vdf-row mobile-no-floating",
            colLeftClass = "left light-font mobile-padding-bottom-10",
            labelClass = "font-normal",
            colRightClass = "right rel mobile-margin-bottom-20",
            colRightId = "top-info-mode"
          },
          {
            label = "Domain Name",
            element = ui_helper.createTextField({
              class="ddns-input-field",
              type="text",
              id="dns-ddns-txt-domain",
              name="ddnsDomain"
              }),
            rowClass = "vdf-row mobile-no-floating",
            colLeftClass = "left light-font mobile-padding-bottom-10",
            labelClass = "font-normal",
            colRightClass = "right mobile-border-kill"
          },
          {
            label = "Account",
            element = ui_helper.createTextField({
              class="ddns-input-field",
              type="text",
              id="dns-ddns-txt-username",
              name="ddnsUsrname"
              }),
            rowClass = "vdf-row mobile-no-floating",
            colLeftClass = "left light-font mobile-padding-bottom-10",
            labelClass = "font-normal",
            colRightClass = "right mobile-border-kill"
          },
          {
            label = "Password",
            element = format('%s %s',ui_helper.createTextField({
              class="ddns-input-field",
              type="password",
              style="display: none;"
              }),ui_helper.createTextField({
              class="ddns-input-field",
              type="password",
              placeholder="********",
              id="dns-ddns-txt-password",
              name="ddnsPswrd"
              })),
            rowClass = "vdf-row mobile-no-floating",
            colLeftClass = "left light-font mobile-padding-bottom-10",
            labelClass = "font-normal",
            colRightClass = "right mobile-border-kill"
          }
        }
        ngx.print(ui_helper.createTable(row, "", "h3-content no-padding-bottom mobile-no-table"))
        ngx.print('\
    </div>\
  </div>\
  ');  
    lp.include("apply-cancel.lp")
    lp.include("reset-wrap-mobile.lp")
    ngx.print('\
</form>\
\
<script type="text/javascript" src="js/global-min.js"></script>\
<script>\
    var variant = "');  ngx.print(vodafone.variant); ngx.print('";\
    var primaryDNS = "');  ngx.print(primaryDNSValue and primaryDNSValue or ""); ngx.print('";\
    var ddnsservice = "');  ngx.print(ddns["ddnsService"]); ngx.print('";\
    var oldUsername = "');  ngx.print(ddns["ddnsUsrname"]); ngx.print('";\
    var domain = "');  ngx.print(ddns["ddnsDomain"]); ngx.print('"\
    var userName = "');  ngx.print(ddnsData["userName"]); ngx.print('";\
    var domainname = "');  ngx.print(ddnsData["Domain"]); ngx.print('";\
    var passWord = "');  ngx.print(ddnsData["password"]); ngx.print('";\
    var service = "');  ngx.print(ddnsData["Service"]); ngx.print('";\
    var ddnsswitch = "');  ngx.print(resetdns["reset_dynamic_dns"]); ngx.print('";\
    var resetusername     = "');  ngx.print(resetdns["reset_account"]); ngx.print('";\
    var resetdomainname   = "');  ngx.print(resetdns["reset_domain_name"]); ngx.print('";\
    var resetpassword     = "');  ngx.print(resetdns["reset_password"]); ngx.print('";\
    var resetsecuredns = "');  ngx.print(resetdns["reset_secure_dns"]); ngx.print('";\
    var ddnsprovider = "');  ngx.print(resetdns["reset_provider"]); ngx.print('";\
    var CSRFvalue = "');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('";\
</script>\
<script type="text/javascript" src= "js/internet/dns_ddns.js"></script>\
'); 