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

local serviceProviders = {
  {"dyndns.org","www.DynDNS.org"},
  {"no-ip.com","www.noIP.com"},
  {"duckdns.org","duckdns.org"},
  {"dnsexit.com","www.dnsexit.com"},
  {"dnsdynamic.org","dnsdynamic.org"},
  {"changeip.com","www.changeip.com"},
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

if ngx.req.get_method() == "POST" then
  local success = true
  ngx.header.content_type = "application/json"
  if ngx.req.get_post_args().ddnsStatus == "1" then
    if not (ddnsData["password"] ~= "" and ngx.req.get_post_args().ddnsPswrd == "") or (ddnsData["userName"] ~=ngx.req.get_post_args().ddnsUsrname) then
      success = validateStringLength(ngx.req.get_post_args().ddnsPswrd)
    end
  end
  if not next(errormsg) and success and ngx.var.content_type and match(ngx.var.content_type, "application/x%-www%-form%-urlencoded") then
    local setTable = {}
    -- set operation for secureDNS enable option and Destination IPAddress.
    if ngx.req.get_post_args().securedns then
      local index = match(secureDns[1].path, ".(%d+).")
      setTable[format("uci.firewall.redirect.%s.enabled",index)] = ngx.req.get_post_args().securedns
      setTable[format("uci.firewall.redirect.%s.dest_ip",index)] = ddnsData.gatewayIP
    end
    if ngx.req.get_post_args().ddnsStatus == "1" then
      local passwd = ngx.req.get_post_args().ddnsPswrd == "" and ddnsData["password"] or ngx.req.get_post_args().ddnsPswrd
      setTable["uci.ddns.service.@myddns_ipv4.password"] = passwd
      setTable["uci.ddns.service.@myddns_ipv4.lookup_host"] = ngx.req.get_post_args().ddnsDomain
    end
    proxy.set(setTable)
      proxy.apply()
    ngx.print('{ "status":"success" }')
  else
    ngx.print('{ "status":"error" }')
  end
  ngx.exit(ngx.HTTP_OK)
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
<script src="js/global.js"></script>\
<script>\
  $(function () {\
    $(\'select\').chosen({\
      disable_search_threshold: 100000,\
      allow_single_deselect: true\
    });\
  });\
</script>\
\
<form id="dns-ddns-form" class="form-horizontal" method="post" action="modals/dns-ddns.lp">\
<!-- <div class="row no-margin-right">\
  <div id="resetBar" class="resetBar resetContainer" style="display:none">\
    <div class="col-md-7 col-xs-12">');  ngx.print(T"Do you want to reset this page to default settings?"); ngx.print('\
    </div>\
    <div class="col-md-5 col-xs-12 text-right no-padding-right">\
      <input value="Reset" title="Reset" class="resetR button button-apply" id="resetR" type="button">\
      <input value="Cancel" title="Cancel" class="cancelR button button-cancel" id="cancelR" type="button">\
    </div>\
  </div>\
</div>-->\
<div class="row no-margin-right">\
  <div class="col-xs-12 col-md-8 col-sm-8">\
    <h1>\
      <span>');  ngx.print(T"DNS"); ngx.print('</span>\
    </h1>\
  </div>\
</div>\
<h2>\
  <span>');  ngx.print(T"The DNS configuration is done automatically when you connect to the network. Alternatively you can manually configure your own DNS settings on your devices."); ngx.print('\
  </span>\
</h2>\
<div class="h3-content h3-content-mobile">\
  <div class="row padding-top-20 padding-top-bottom-20">\
    <div class="col-xs-6 col-sm-6 col-md-6">\
      <span>');  ngx.print(T"Secure DNS"); ngx.print('</span>\
    </div>\
    <div class="col-xs-6 col-md-6 col-sm-6 pull-right">\
      <div class="button ');  if secureDns[1].enabled ~= "0" then   ngx.print(' button-on ');  else  ngx.print('button-off ');  end  ngx.print(' toggle-content-button pull-right" id="ddns-btn-sdns">\
      </div>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20 no-margin-right" id="ddns-div-sdns">\
    <div class="col-xs-12 col-md-12 col-sm-12 dmz-message-info">\
      <div class="message-info">\
        <span>');  ngx.print(T"Keep Secure DNS setting to ON in order to prevent malware to infect your devices and direct your Internet traffic to malicious websites. You can turn it OFF if you wish to manually configure the DNS on your devices."); ngx.print('\
        </span>\
      </div>\
    </div>\
  </div>\
</div>\
\
<h1>');  ngx.print(T"DDNS (Dynamic DNS)"); ngx.print('</h1>\
<h2>');  ngx.print(T"DDNS allows you to access your Vodafone Ultra Hub from the Internet using a domain name instead of IP address. You will need an account on a DDNS service provider."); ngx.print('</h2>\
<div class="padding-bottom-wrap">\
  <div class="h3-content no-padding-bottom" style="display:table;">\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"Dynamic DNS"); ngx.print('</span>      </div>\
      <div class="right">\
	   <div id="dns-ddns-btn-ddns_enable" class="button ');  if ddns.ddnsStatus == "1" then   ngx.print('button-on');  else   ngx.print(' button-off ');  end   ngx.print('" name="ddnsStatus"> </div>\
      </div>\
    </div>\
  </div>\
  <div class="ddnsContent ddns_account_details level-3 shadowProblem" ');  if ddns.ddnsStatus ~= "1" then  ngx.print('style="display:none"');  end  ngx.print(' >\
    <div class="h3-content no-padding-bottom mobile-no-table" style="display:table;">\
      <div class="vdf-row mobile-no-floating">\
        <div class="left light-font mobile-padding-bottom-10">\
          <span class="font-normal">');  ngx.print(T"Provider"); ngx.print('</span>\
        </div>\
        <div id="top-info-mode" class="right rel mobile-margin-bottom-20">\
          <select class="dropdown" id="dns-ddns-select-service" name="ddnsService" style="width: 200px;" >\
          ');  for _,v in ipairs(serviceProviders) do
            ngx.print(string.format("<option value='%s'>%s</option>",v[1],v[2]))
          end  ngx.print('\
          </select>\
        </div>\
      </div>\
      <div class="vdf-row mobile-no-floating">\
        <div class="left light-font mobile-padding-bottom-10">\
          <span class="font-normal">');  ngx.print(T"Domain Name"); ngx.print('</span>        </div>\
        <div class="right mobile-border-kill">\
		  <input class="ddns-input-field" type="text" id="dns-ddns-txt-domain" name="ddnsDomain">\
        </div>\
      </div>\
      <div class="vdf-row mobile-no-floating">\
        <div class="left light-font mobile-padding-bottom-10">\
          <span class="font-normal">');  ngx.print(T"Account"); ngx.print('</span>\
        </div>\
        <div class="right mobile-border-kill">\
          <input class="ddns-input-field" type="text" id="dns-ddns-txt-username" name="ddnsUsrname">\
        </div>\
      </div>\
      <div class="vdf-row mobile-no-floating">\
        <div class="left light-font mobile-padding-bottom-10">\
          <span class="font-normal">');  ngx.print(T"Password"); ngx.print('</span>        </div>\
        <div class="right mobile-border-kill">\
          <input class="ddns-input-field" type="password" placeholder="********" style="display: none;">\
          <input class="ddns-input-field" type="password" id="dns-ddns-txt-password" name="ddnsPswrd" placeholder="********">\
        </div>\
      </div>\
          </div>\
  </div>\
</div>\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
</form>\
\
<script type="text/javascript" src="js/global.js"></script>\
<script>\
var resetPage = false;\
$(function() {\
  $(\'input,textarea\').focus(function () {\
    $(this).data(\'placeholder\', $(this).attr(\'placeholder\')).attr(\'placeholder\', \'\');\
  }).blur(function () {\
    $(this).attr(\'placeholder\', $(this).data(\'placeholder\'));\
  });\
  var ddnsservice = "');  ngx.print(ddns["ddnsService"]); ngx.print('";\
  var oldUsername = "');  ngx.print(ddns["ddnsUsrname"]); ngx.print('";\
  if (ddnsservice.length == 0)\
  {\
    $("#dns-ddns-select-service option:first").prop("selected", true);\
    $("#dns-ddns-select-service").trigger("chosen:updated");\
  }\
  else\
  {\
    $("#dns-ddns-select-service").val(ddnsservice).trigger("chosen:updated");\
    $("#dns-ddns-select-service").trigger("chosen:updated");\
  }\
  document.getElementById("dns-ddns-txt-username").value = "');  ngx.print(ddns["ddnsUsrname"]); ngx.print('";\
  document.getElementById("dns-ddns-txt-domain").value = "');  ngx.print(ddns["ddnsDomain"]); ngx.print('";\
\
  $("#dns-ddns-select-service").change(function(){\
    $(".h3-content input").each(function(){ $(this).val("");});\
    $(".ddns-input-field").removeClass("input-length");\
  });\
\
  $("#dns-ddns-btn-ddns_enable").click(function() {\
    if($(this).hasClass(\'button-on\'))\
    {\
      $(this).removeClass(\'button-on\');\
      $(this).toggleClass(\'button-off\');\
      $(".ddns_account_details").slideUp("400");\
    }\
    else\
    {\
      $(this).removeClass(\'button-off\');\
      $(this).toggleClass(\'button-on\');\
      $(".ddns_account_details").slideDown("400");\
    }\
  });\
  if ($("#ddns-btn-sdns").hasClass(\'button-on\')) {\
    $("#ddns-div-sdns").removeClass("show").addClass("hide");\
  }  else {\
    $("#ddns-div-sdns").removeClass("hide").addClass("show");\
  }\
  $("#ddns-btn-sdns").click(function(){\
    if($(this).hasClass(\'button-on\'))\
    {\
      $(this).removeClass(\'button-on\');\
      $(this).toggleClass(\'button-off\');\
      $("#ddns-div-sdns").removeClass("hide").addClass("show");\
    }else\
    {\
      $(this).removeClass(\'button-off\');\
      $(this).toggleClass(\'button-on\');\
      $("#ddns-div-sdns").removeClass("show").addClass("hide");\
    }\
  });\
\
  $("#global-apply").click(function() {\
    $(".ddns-input-field").removeClass("input-length");\
    $(".articlediv, .articlediv > .msg-error").removeClass("show").addClass("hide");\
    var iserror = false;\
    var paramsForPost = [];\
    var ddnsProvider, username, domainName, password;\
    var securednsstatus = $("#ddns-btn-sdns").hasClass("button-on") ? 1 : 0;\
    if ($("#dns-ddns-btn-ddns_enable").hasClass("button-on"))\
    {\
      ddnsSwitch = "1";\
    }\
    else\
    {\
      ddnsSwitch   = "0";\
      username     = "');  ngx.print(ddnsData["userName"]); ngx.print('";\
      domainName   = "');  ngx.print(ddnsData["Domain"]); ngx.print('";\
      password     = "');  ngx.print(ddnsData["password"]); ngx.print('";\
      ddnsProvider = "');  ngx.print(ddnsData["Service"]); ngx.print('";\
    }\
    var target = $("#dns-ddns-form").attr("action");\
    if(!resetPage) {\
    if (ddnsSwitch == "1")\
    {\
      ddnsProvider = document.getElementById("dns-ddns-select-service").value;\
      username     = document.getElementById("dns-ddns-txt-username").value;\
      domainName   = document.getElementById("dns-ddns-txt-domain").value;\
      password     = document.getElementById("dns-ddns-txt-password").value;\
\
      if ((oldUsername != username) || (oldUsername.length == 0 && username.length == 0))\
      {\
        if (!(password.length > 0 && password.length <=255))\
        {\
          $("#dns-ddns-txt-password").addClass("input-length");\
           iserror = true;\
        }\
      }\
      if (!(username.length > 0 && username.length <=255))\
      {\
        $("#dns-ddns-txt-username").addClass("input-length");\
        iserror = true;\
      }\
      var domain = domainName.split(".");\
      if (domainName.length > 0 && domainName.length <=255 && domain.length!=1)\
      {\
        var i = 0;\
        while(i < domain.length)\
        {\
          if (domain[i].length > 1)\
          {\
            var correctLabel = domain[i].match("^[a-zA-z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9]");\
            if (domain[i] != correctLabel || domain[i].length > 63)\
            {\
              $("#dns-ddns-txt-domain").addClass("input-length");\
              return;\
            }\
          }\
          else if(domain[i].length == 1)\
          {\
            if (domain[i].match("[a-zA-Z0-9]"))\
            {\
              $("#dns-ddns-txt-domain").addClass("input-length");\
              return;\
            }\
          }\
          else\
          {\
            $("#dns-ddns-txt-domain").addClass("input-length");\
            return;\
          }\
          i=i+1;\
        }\
      }\
      else\
      {\
        $("#dns-ddns-txt-domain").addClass("input-length");\
        return;\
      }\
      if (iserror == true)\
        return;\
    }\
    }\
    else {\
      securednsstatus = "');  ngx.print(resetdns["reset_secure_dns"]); ngx.print('";\
      ddnsSwitch   = "');  ngx.print(resetdns["reset_dynamic_dns"]); ngx.print('";\
      username     = "');  ngx.print(resetdns["reset_account"]); ngx.print('";\
      domainName   = "');  ngx.print(resetdns["reset_domain_name"]); ngx.print('";\
      password     = "');  ngx.print(resetdns["reset_password"]); ngx.print('";\
      ddnsProvider = "');  ngx.print(resetdns["reset_provider"]); ngx.print('";\
    }\
    paramsForPost.push({\
      name : "ddnsStatus",\
      value : ddnsSwitch\
    },\
    {\
      name: "ddnsService",\
      value : ddnsProvider\
    },\
    {\
      name: "ddnsDomain",\
      value : domainName\
    },\
    {\
      name: "ddnsUsrname",\
      value : username\
    },\
    {\
      name: "ddnsPswrd",\
      value : password\
    },\
    {\
      name: "securedns",\
      value : securednsstatus\
    },\
    {\
    name : "action",\
    value : "SAVE"\
    },\
    {\
    name : "CSRFtoken",\
    value : "');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('"\
    });\
    postHandler(target,paramsForPost,true);\
    });\
    $("#global-cancel").click(function(){\
      $("#content").load("/modals/dns-ddns.lp");\
    });\
});\
$("#resetR, .resetR").click(function() {\
  resetPage = true;\
  $("#dns-ddns-select-service").val("');  ngx.print(resetdns["reset_provider"]); ngx.print('").trigger("chosen:updated");\
  $("#dns-ddns-txt-domain").val("');  ngx.print(resetdns["reset_domain_name"]); ngx.print('");\
  $("#dns-ddns-txt-username").val("');  ngx.print(resetdns["reset_account"]); ngx.print('");\
  $("#dns-ddns-txt-password").val("');  ngx.print(resetdns["reset_password"]); ngx.print('");\
  $("#dns-ddns-btn-ddns_enable").val("');  ngx.print(resetdns["reset_dynamic_dns"]); ngx.print('");\
  $("#ddns-btn-sdns").val("');  ngx.print(resetdns["reset_secure_dns"]); ngx.print('");\
  if ("');  ngx.print(resetdns["reset_dynamic_dns"]); ngx.print('" == "1") {\
    $(\'#dns-ddns-btn-ddns_enable\').addClass(\'button-on\').removeClass(\'button-off\');\
    $(\'.ddnsContent\').show();\
  }\
  else\
  {\
    $(\'#dns-ddns-btn-ddns_enable\').addClass(\'button-off\').removeClass(\'button-on\');\
    $(\'.ddnsContent\').hide();\
  }\
  if ("');  ngx.print(resetdns["reset_secure_dns"]); ngx.print('" == "1") {\
    $(\'#ddns-btn-sdns\').addClass(\'button-on\').removeClass(\'button-off\');\
    $("#ddns-div-sdns").removeClass("hide").addClass("show");\
  }\
  else\
  {\
    $(\'#ddns-btn-sdns\').addClass(\'button-off\').removeClass(\'button-on\');\
    $("#ddns-div-sdns").removeClass("show").addClass("hide");\
  }\
});\
</script>\
'); 