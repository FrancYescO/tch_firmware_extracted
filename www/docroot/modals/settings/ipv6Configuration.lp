--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local post_helper = require("web.post_helper")
local validateBoolean = post_helper.validateBoolean
local numberInRange = post_helper.getValidateNumberInRange
local positiveNum = post_helper.validatePositiveNum
local andValidation = post_helper.getAndValidation
local validateStringIsIP = post_helper.validateStringIsIP
local session = ngx.ctx.session
local ngx = ngx
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local match = string.match
local ipv6Params = {
  ipv6Status = "rpc.network.ipv6_enable",
}
local ipv6Validations = {
    ipv6Status = validateBoolean,
}
local IPv6Enable, enableErrmsg = {}, {}
local enableValue

-- Covering Post triggered via ipv6 buttom and check if state is changed. In that case  we edit the status else we keep the stored value.

if ngx.req.get_method() ~= "POST" or session:retrieve("ipv6Enb") ~=  ngx.req.get_post_args().ipv6Status  then
  IPv6Enable, enableErrmsg = post_helper.handleQuery(ipv6Params, ipv6Validations)
  session:store("ipv6Enb", IPv6Enable["ipv6Status"] )
  enableValue = IPv6Enable["ipv6Status"]
else
  enableValue = session:retrieve("ipv6Enb");
end

local function validationForMinRtr(value, postdata, key)
  if (positiveNum(tonumber(postdata["MaxRtrAdvInterval"])) and  string.match(postdata["MaxRtrAdvInterval"], "^%d+$")) then
    local maxValue = tonumber(postdata["MaxRtrAdvInterval"])*0.75
    local funcValidation = numberInRange(3, math.floor(maxValue))
    if funcValidation(value) then
      return true
    else
      return nil, T"Number not in Range"
    end
  end
  return nil, T"Not a number"
end

local function numberValidation(value, postdata, key)
  if positiveNum(tonumber(value)) then
    if string.match(value,"^%d+$") then
      return true
    end
  end
  return nil
end

-- Check the state of ra_server is one of the following {server,disabled,relay,hybrid}
-- Return the actual value if true else return false
local function routerEnableValidation(value, postdata)
  local raState = { "server", "disabled", "relay", "hybrid" }
  return raState[value] and true or false
end

local getVariantParams = {
  variant   = "uci.env.var.vodafone_variant",
  Ipv6Prefix = "uci.network.interface.@lan.ip6prefix"
}
content_helper.getExactContent(getVariantParams)
local params = {
  rapidCommit        = "rpc.dhcpv6.client.@wan6.RapidCommit",
  IAPD               = "rpc.dhcpv6.client.@wan6.RequestPrefixes",
  clientDNS          = "rpc.dhcpv6.client.@wan6.DNS",
  --IANA             = "", --TODO
  -- serverDNS       = "", --TODO
  AdvManagedFlag     = "rpc.ra_interface.@lan.adv_managed_flag",
  AdvOtherConfigFlag = "rpc.ra_interface.@lan.adv_other_config_flag",
  AdvDefaultLifetime = "rpc.ra_interface.@lan.adv_default_lifetime",
  AdvLinkMTU         = "rpc.ra_interface.@lan.adv_link_mtu",
  MaxRtrAdvInterval  = "rpc.ra_interface.@lan.max_rtr_adv_interval",
  MinRtrAdvInterval  = "rpc.ra_interface.@lan.min_rtr_adv_interval",
  --AdvPreferredLifetime = "", --TODO
  --AdvValidLifetime  = "", --TODO
}

local validations = {
  rapidCommit        = validateBoolean,
  IAPD               = validateBoolean,
  clientDNS          = validateBoolean,
  -- IANA             = validateBoolean, --TODO
  -- serverDNS        = validateBoolean, --TODO
  AdvManagedFlag     = validateBoolean,
  AdvOtherConfigFlag = validateBoolean,
  AdvDefaultLifetime = andValidation(numberValidation , numberInRange(0,65535)),
  AdvLinkMTU         = andValidation(numberValidation , numberInRange(0,65535)),
  MaxRtrAdvInterval  = andValidation(numberValidation , numberInRange(4,1800)),
  MinRtrAdvInterval  = andValidation(numberValidation , validationForMinRtr),
  -- AdvPreferredLifetime = "", --TODO
  -- AdvValidLifetime  = "", -- TODO
}

local IPv6Info, IPv6Errmsg = {}, {}
local IPv6InfoVHA, IPv6ErrmsgVHA = {}, {} -- Params applicable only for VHA
local IPv6Prefix, IPv6PrefixLen
local IPv6PrefixErr = true
--In Every post action it will check status for ipv6Button. If ipv6 status is in ON then
-- post action for other parameters will get excuted. So we can block unwanted set operations.
local resetipv6 = {
  reset_ipv6 = "uci.uci-defaults.ipv6.ipv6",
  reset_rapid_commit = "uci.uci-defaults.ipv6.rapid_commit",
  reset_ia_pd = "uci.uci-defaults.ipv6.ia_pd",
  reset_dns = "uci.uci-defaults.ipv6.dns",
  reset_advmanagedcall = "uci.uci-defaults.ipv6.advmanagedcall",
  reset_advotherconfigflag = "uci.uci-defaults.ipv6.advotherconfigflag",
  reset_advdefaultlifetime = "uci.uci-defaults.ipv6.advdefaultlifetime",
  reset_advlinkmtu = "uci.uci-defaults.ipv6.advlinkmtu",
  reset_maxrtradvinterval = "uci.uci-defaults.ipv6.maxrtradvinterval",
  reset_minrtradvinterval = "uci.uci-defaults.ipv6.minrtradvinterval"
}
content_helper.getExactContent(resetipv6)
-- The following Params are applicable only for VHA Expert and Admin mode
if getVariantParams["variant"] == "VHA" then
  if ngx.req.get_method() == "POST" then
    local postargs = ngx.req.get_post_args()
    if postargs.Ipv6Prefix == "" and postargs.Ipv6PrefixLen == nil then
      proxy.set("uci.network.interface.@lan.ip6prefix", "")
      proxy.apply()
    elseif validateStringIsIP(postargs["Ipv6Prefix"]) and numberValidation(postargs["IPv6PrefixLen"]) then
      local prefixVal = postargs["Ipv6Prefix"] .."/" .. postargs["IPv6PrefixLen"]
      proxy.set("uci.network.interface.@lan.ip6prefix", prefixVal)
      proxy.apply()
    else
      IPv6PrefixErr = false
    end
  end
  local paramsExtended = {
    Ipv6DefaultGW = "uci.network.interface.@lan.ip6gw",
    ra_enable = "rpc.ra_interface.@lan.ra_enable"
  }

  local extendedParamsValidations = {
    Ipv6DefaultGW   = post_helper.getOptionalValidation(validateStringIsIP),
    ra_enable       = routerEnableValidation
  }
  IPv6InfoVHA, IPv6ErrmsgVHA = post_helper.handleQuery(paramsExtended, extendedParamsValidations)
  local getPrefixValue = getVariantParams["Ipv6Prefix"]
  IPv6Prefix , IPv6PrefixLen = match(getPrefixValue,"([%w%:]+)%/(%d+)")
  if not IPv6Prefix then
    IPv6Prefix, IPv6PrefixLen = "", ""
  end
end

  IPv6Info, IPv6Errmsg = post_helper.handleQuery(params, validations)
if not next(IPv6Errmsg) and not next(enableErrmsg) and not next(IPv6ErrmsgVHA) and IPv6PrefixErr then
  ngx.print('<input type="hidden" id="post_status" value="success">')
else
  ngx.print('<input type="hidden" id="post_status" value="error">')
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
<div class="row no-margin-right content-ipv6-basic-configuration">\
  <div class="col-xs-12 col-md-12 col-sm-12">\
    <h1>\
      <span>');  ngx.print(T"IPv6"); ngx.print('</span></h1>\
  </div>\
</div>\
<h2>&nbsp;</h2>\
<form  id = "ipv6Form" action="modals/settings/ipv6Configuration.lp">\
<input type="hidden" name="CSRFtoken" value ="');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"></input>\
<input type="hidden" name="action" value ="SAVE"></input>\
<div class="h3-content h3-content-mobile">\
    <div class="row padding-top-bottom-20 ">\
        <div class="col-md-6 col-sm-6 col-xs-6">\
            <span>');  ngx.print(T"IPv6"); ngx.print('</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-6 align-right">\
            <input type="hidden" name="ipv6Status" value ="');  ngx.print(enableValue); ngx.print('" id="ipv6-txt-status" ></input>\
            <div id="ipv6-btn-status" ');  if enableValue == "1" then  ngx.print(' class="button button-on button-ipv6" ');  else  ngx.print(' class="button button-off button-ipv6" ');  end  ngx.print(' >\
        </div>\
        </div>\
    </div>\
</div>\
\
\
<div id = "ipv6-div" class="show">\
<h3><span>');  ngx.print(T"DHCPv6 Client Request Options"); ngx.print('</span></h3>\
<div class="h3-content h3-content-mobile">\
  <div class="row padding-top-bottom-20 ">\
        <div class="col-md-6 col-sm-6 col-xs-6">\
            <span>');  ngx.print(T"Rapid commit"); ngx.print('</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-6 text-right">\
            <input type="hidden" id= "ipv6-txt-rpdcmt" name="rapidCommit" value ="');  ngx.print(IPv6Info.rapidCommit); ngx.print('"></input>\
            <div id= "ipv6-btn-rpdcmt" ');  if IPv6Info.rapidCommit == "1" then  ngx.print(' class="button button-on button-ipv6" ');  else  ngx.print(' class="button button-off button-ipv6" ');  end  ngx.print('></div>\
        </div>\
</div>\
    <div class="row">\
        <div class="col-md-12">\
            <hr/>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 ">\
        <div class="col-md-6 col-sm-6 col-xs-6">\
            <span>');  ngx.print(T"IA_PD"); ngx.print('</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-6 text-right">\
    <input type="hidden" name="IAPD" id ="ipv6-txt-iapd" value ="');  ngx.print(IPv6Info.IAPD); ngx.print('"></input>\
            <div ');  if IPv6Info.IAPD == "1" then  ngx.print(' class="button button-on button-ipv6" ');  else  ngx.print(' class="button button-off button-ipv6" ');  end  ngx.print(' id="ipv6-btn-iapd"></div>\
        </div>\
</div>\
<!--<div class="row padding-top-bottom-20 ">\
        <div class="col-md-6 col-sm-6 col-xs-12">\
            <span>');  ngx.print(T"IA_PD prefix mode"); ngx.print('</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-12 text-right basic-configuration-mobile-left">\
            <input id="prefix-hide" class="radio" data-id="1" name="event-to-show" type="radio" >\
              <label for="prefix-hide"></label>\
              <span>');  ngx.print(T"Preferred"); ngx.print('</span>\
                <input id="prefix-show" class="radio" data-id="1" name="event-to-show" type="radio">\
              <label for="prefix-show"></label>\
              <span>');  ngx.print(T"Random"); ngx.print('</span>\
        </div>\
</div>\
<div class="row padding-bottom-20">\
        <div class="col-md-12 col-sm-12 col-xs-12 text-right basic-configuration-mobile-left">\
        <div id="top-info-mode" class="rel">\
          <select>\
            <option>');  ngx.print(T"on reconnect"); ngx.print('</option>\
            <option>');  ngx.print(T"on DHCP renew"); ngx.print('</option>\
            <option>');  ngx.print(T"timer based"); ngx.print('</option>\
          </select>\
        </div>\
        </div>\
\
\
</div>\
  <div class="row padding-top-bottom-20 ">\
    <div class="col-md-12 col-sm-12 col-xs-12 text-right basic-configuration-mobile-left">\
      <input class="button button-cancel" value="English" type="button">\
    </div>\
  </div>-->\
  <div class="row padding-top-bottom-20 ">\
    <div class="col-md-6 col-sm-6 col-xs-6">\
      <span>');  ngx.print(T"DNS"); ngx.print('</span>\
    </div>\
    <div class="col-md-6 col-sm-6 col-xs-6 text-right">\
      <input type="hidden" name="clientDNS"  id = "ipv6-txt-clntdns" value ="');  ngx.print(IPv6Info.clientDNS); ngx.print('"></input>\
      <div  ');  if IPv6Info.clientDNS == "1" then  ngx.print(' class="button button-on button-ipv6" ');  else  ngx.print(' class="button button-off button-ipv6" ');  end  ngx.print(' id= "ipv6-btn-clntdns"></div>\
    </div>\
    </div>\
  ');  if (getVariantParams["variant"]) == "VHA" then  ngx.print('\
  <div class="row padding-top-bottom-20 ">\
    <div class="col-md-6 col-sm-6 col-xs-12">\
      <span class="mobile-padding-bottom-10">');  ngx.print(T"Ipv6 Prefix"); ngx.print('</span>\
    </div>\
    <div class="col-md-6 col-sm-6 col-xs-12 text-right basic-configuration-mobile-left">\
      <input type="text" name="Ipv6Prefix" value="');  ngx.print(IPv6Prefix); ngx.print('" id="ipv6-txt-Ipv6Prefix">\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20 ">\
    <div class="col-md-6 col-sm-6 col-xs-12">\
      <span class="mobile-padding-bottom-10">');  ngx.print(T"Ipv6 Prefix Length"); ngx.print('</span>\
    </div>\
    <div class="col-md-6 col-sm-6 col-xs-12 text-right basic-configuration-mobile-left">\
      <input type="text" name="IPv6PrefixLen" class="num-only" value="');  ngx.print(IPv6PrefixLen); ngx.print('" id="ipv6-txt-Ipv6PrefixLen">\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20 ">\
    <div class="col-md-6 col-sm-6 col-xs-12">\
      <span class="mobile-padding-bottom-10">');  ngx.print(T"Ipv6 Default Gateway"); ngx.print('</span>\
    </div>\
    <div class="col-md-6 col-sm-6 col-xs-12 text-right basic-configuration-mobile-left">\
      <input type="text" name="Ipv6DefaultGW" value="');  ngx.print(IPv6InfoVHA.Ipv6DefaultGW); ngx.print('" id="ipv6-txt-Ipv6DefaultGW">\
    </div>\
  </div>\
  ');  end  ngx.print('\
</div>\
<!--\
<div class="h3-content h3-content-mobile">\
  <h3><span>');  ngx.print(T"DHCPv6 Server Delegation Options"); ngx.print('</span></h3>\
  <div class="row padding-top-bottom-20 ">\
    <div class="col-md-6 col-sm-6 col-xs-6">\
      <span>');  ngx.print(T"IA_NA"); ngx.print('</span>\
      </div>\
      <div class="col-md-6 col-sm-6 col-xs-6 text-right">\
        <input type="hidden" name="IANA"  id="ipv6-txt-iana" value ="');  ngx.print(); ngx.print('"></input>\
        <div  ');  if IPv6Info.IAPD == "1" then  ngx.print(' class="button button-on button-ipv6" ');  else  ngx.print(' class="button button-off button-ipv6" ');  end  ngx.print(' id="ipv6-btn-iana"></div>\
      </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20 ">\
    <div class="col-md-6 col-sm-6 col-xs-6">\
      <span>');  ngx.print(T"DNS"); ngx.print('</span>\
    </div>\
    <div class="col-md-6 col-sm-6 col-xs-6 text-right">\
      <input type="hidden" name="serverDNS" id="ipv6-txt-serdns" value ="');  ngx.print(); ngx.print('"></input>\
      <div  ');  if IPv6Info.IAPD == "1" then  ngx.print(' class="button button-on button-ipv6" ');  else  ngx.print(' class="button button-off button-ipv6" ');  end  ngx.print(' id="ipv6-btn-serdns"></div>\
    </div>\
  </div>\
</div>-->\
<h3><span>');  ngx.print(T"Router Advertisement Options"); ngx.print('</span></h3>\
<div class="h3-content h3-content-mobile">\
  ');  if (getVariantParams["variant"]) == "VHA" then  ngx.print('\
    <div class="row padding-top-bottom-20">\
      <div class="col-md-6 col-sm-6 col-xs-6">\
        <span>');  ngx.print(T"Router Advertisement"); ngx.print('</span>\
      </div>\
      <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
        <input type="hidden" name="ra_enable" id="ipv6-txt-raenable" value ="');  ngx.print(IPv6InfoVHA.ra_enable); ngx.print('"></input>\
        <div ');  if IPv6InfoVHA.ra_enable == "server" then   ngx.print(' class="button button-on" ');  else  ngx.print(' class="button button-off" ');  end  ngx.print(' id="routeradd-btn-enable">\
        </div>\
      </div>\
    </div>\
  ');  end  ngx.print('\
  <div id="hide-adv-managedflag" class="show">\
  <div class="row padding-top-bottom-20 ">\
    <div class="col-md-6 col-sm-6 col-xs-6">\
      <span>');  ngx.print(T"AdvManagedFlag"); ngx.print('</span>\
    </div>\
    <div class="col-md-6 col-sm-6 col-xs-6 text-right">\
  <input type="hidden" name="AdvManagedFlag" id="ipv6-txt-advmangflag" value ="');  ngx.print(IPv6Info.AdvManagedFlag); ngx.print('"></input>\
      <div  ');  if IPv6Info.AdvManagedFlag == "1" then  ngx.print(' class="button button-on button-ipv6" ');  else  ngx.print(' class="button button-off button-ipv6" ');  end  ngx.print('  id ="ipv6-btn-advmangflag"></div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20 ">\
    <div class="col-md-6 col-sm-6 col-xs-6">\
      <span>');  ngx.print(T"AdvOtherConfigFlag"); ngx.print('</span>\
    </div>\
    <div class="col-md-6 col-sm-6 col-xs-6 text-right">\
  <input type="hidden" name="AdvOtherConfigFlag" id="ipv6-txt-advconfflag" value ="');  ngx.print(IPv6Info.AdvOtherConfigFlag); ngx.print('"></input>\
      <div  ');  if IPv6Info.AdvOtherConfigFlag == "1" then  ngx.print(' class="button button-on button-ipv6" ');  else  ngx.print(' class="button button-off button-ipv6" ');  end  ngx.print(' id ="ipv6-btn-advconfflag"></div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20 ">\
    <div class="col-md-6 col-sm-6 col-xs-12">\
      <span class="mobile-padding-bottom-10">');  ngx.print(T"AdvDefaultLifetime"); ngx.print('</span>\
    </div>\
    <div class="col-md-6 col-sm-6 col-xs-12 text-right basic-configuration-mobile-left">\
      <input type="text" name="AdvDefaultLifetime" class="num-only" value="');  ngx.print(IPv6Info.AdvDefaultLifetime); ngx.print('" id="ipv6-txt-dfltlifetime">\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
\
  <div class="row padding-top-bottom-20 ">\
    <div class="col-md-6 col-sm-6 col-xs-12">\
      <span class="mobile-padding-bottom-10">');  ngx.print(T"AdvLinkMTU"); ngx.print('</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-12 text-right basic-configuration-mobile-left">\
          <input  type="text" name= "AdvLinkMTU" class="num-only" value="');  ngx.print(IPv6Info.AdvLinkMTU); ngx.print('" id="ipv6-txt-advlnkmtu">\
        </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20">\
      <div class="col-md-6 col-sm-6 col-xs-12">\
      <span class="mobile-padding-bottom-10">');  ngx.print(T"MaxRtrAdvInterval"); ngx.print('</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-12 text-right basic-configuration-mobile-left">\
          <input type="text" name="MaxRtrAdvInterval" class="num-only" value="');  ngx.print(IPv6Info.MaxRtrAdvInterval); ngx.print('" id ="ipv6-txt-maxrtradvint">\
        </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
          <hr/>\
        </div>\
    </div>\
    <div class="row padding-top-bottom-20 ">\
      <div class="col-md-6 col-sm-6 col-xs-12">\
        <span class="mobile-padding-bottom-10">');  ngx.print(T"MinRtrAdvInterval"); ngx.print('</span>\
      </div>\
      <div class="col-md-6 col-sm-6 col-xs-12 text-right basic-configuration-mobile-left">\
        <input type="text" name="MinRtrAdvInterval" class="num-only" value="');  ngx.print(IPv6Info.MinRtrAdvInterval); ngx.print('" id="ipv6-txt-minrtradvint">\
      </div>\
    </div>\
  </div>\
      <!--<div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20">\
      <div class="col-md-6 col-sm-6 col-xs-12">\
        <span class="mobile-padding-bottom-10">');  ngx.print(T"AdvPreferredLifetime"); ngx.print('</span>\
      </div>\
      <div class="col-md-6 col-sm-6 col-xs-12 text-right basic-configuration-mobile-left">\
        <input  type="text" name="AdvPreferredLifetime"   value="');  ngx.print(); ngx.print('" id="ipv6-txt-advpreliftme">\
      </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 ">\
      <div class="col-md-6 col-sm-6 col-xs-12">\
        <span class="mobile-padding-bottom-10">');  ngx.print(T"AdvValidLifetime"); ngx.print('</span>\
      </div>\
      <div class="col-md-6 col-sm-6 col-xs-12 text-right basic-configuration-mobile-left">\
        <input  type="text" name= "AdvValidLifetime"   value="');  ngx.print(); ngx.print('" id="ipv6-txt-advvalidliftme">\
      </div>\
    </div> -->\
</div>\
</div>\
</form>\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
<script src="js/global-min.js"></script>\
<script>\
  var variant = "');  ngx.print(getVariantParams["variant"]); ngx.print('";\
  var ra_status = "');  ngx.print(IPv6InfoVHA.ra_enable); ngx.print('";\
  if ( variant === "VHA" && ra_status === "disabled" )\
  {\
    $("#hide-adv-managedflag").removeClass(\'show\').addClass(\'hide\');\
  }\
  $(function () {\
    $(\'select\').chosen({\
      disable_search_threshold: 100000,\
      allow_single_deselect: true\
    });\
  });\
\
$("#routeradd-btn-enable").click(function(){\
    if ($(this).hasClass(\'button-on\'))\
    {\
      $("#ipv6-txt-raenable").val("disabled");\
    }\
    else\
    {\
      $("#ipv6-txt-raenable").val("server");\
    }\
    $(this).toggleClass(\'button-on button-off\');\
    $("#hide-adv-managedflag").toggleClass(\'hide show\');\
});\
\
$(".button-ipv6").click(function(){\
  var currentid  = $(this).attr("id");\
  var hiddenid= $(this).prev().attr("id");\
  btn_on_off($(this));\
  if( currentid == "ipv6-btn-status"){\
\
    if ($("#"+currentid).hasClass("button-on") ){\
      $("#ipv6-div").removeClass("hide").addClass("show");\
    }\
    else {\
      $("#ipv6-div").removeClass("show").addClass("hide");\
    }\
  }\
  if ($(this).hasClass("button-on")){\
    $("#"+hiddenid).val("1");\
  }\
  else{\
    $("#"+hiddenid).val("0");\
  }\
});\
var enableVal = "');  ngx.print(enableValue); ngx.print('"\
\
if (enableVal == "1"){\
  $("#ipv6-div").removeClass("hide").addClass("show");\
}\
else{\
  $("#ipv6-div").removeClass("show").addClass("hide");\
}\
\
function validateIpv6(value){\
  return /^([0-9a-f]|:){1,4}(:([0-9a-f]{0,4})*){1,7}$/.test(value);\
 }\
\
$("#global-apply, #modal-apply").click(function() {\
  var elements = {\
    AdvDefaultLifetime : "#ipv6-txt-dfltlifetime",\
    AdvLinkMTU         : "#ipv6-txt-advlnkmtu",\
    MaxRtrAdvInterval  : "#ipv6-txt-maxrtradvint",\
    MinRtrAdvInterval  : "#ipv6-txt-minrtradvint",\
    IPv6PrefixLen      : "#ipv6-txt-Ipv6PrefixLen:visible",\
    Ipv6Prefix         : "#ipv6-txt-Ipv6Prefix",\
    Ipv6DefaultGW      : "#ipv6-txt-Ipv6DefaultGW"\
  }\
  var validations = {\
    AdvDefaultLifetime : validateNumberRange(0, 65535),\
    AdvLinkMTU         : validateNumberRange(0, 65535),\
    MaxRtrAdvInterval  : validateNumberRange(4, 1800),\
    MinRtrAdvInterval  : validateNumberRange(3, Math.floor($("#ipv6-txt-maxrtradvint").val() * 0.75)),\
    IPv6PrefixLen      : function(value) { return value == "" || validateNumberRange(0, 64)(value) },\
    Ipv6Prefix         : function(value) { return value == "" || validateIpv6(value) },\
    Ipv6DefaultGW      : function(value) { return value == "" || validateIpv6(value) }\
}\
  if (!validateElements(elements, validations)) return false;\
  postHandler($("#ipv6Form").attr("action"),$("#ipv6Form").serializeArray());\
  var arr = $("#ipv6Form").serializeArray();\
});\
\
$("#global-cancel").click(function(){\
  $("#content").load("/modals/settings/ipv6Configuration.lp");\
})\
$("#resetR, .resetR").click(function(){\
  function changeButton(id, value, hiddenClass, hiddenField) {\
    $(id).val(value);\
    if (value == "1") {\
      $(id).addClass(\'button-on\').removeClass(\'button-off\');\
      $(hiddenClass).val("1");\
      $(hiddenField).removeClass("hide").addClass("show");\
    } else {\
      $(id).addClass(\'button-off\').removeClass(\'button-on\');\
      $(hiddenClass).val("0");\
      $(hiddenField).removeClass("show").addClass("hide");\
    }\
  }\
  changeButton("#ipv6-btn-status", ');  ngx.print(resetipv6["reset_ipv6"]); ngx.print(', "#ipv6-txt-status", "#ipv6-div");\
  changeButton("#ipv6-btn-rpdcmt", ');  ngx.print(resetipv6["reset_rapid_commit"]); ngx.print(', "#ipv6-txt-rpdcmt");\
  changeButton("#ipv6-btn-iapd", ');  ngx.print(resetipv6["reset_ia_pd"]); ngx.print(', "#ipv6-txt-iapd");\
  changeButton("#ipv6-btn-clntdns", ');  ngx.print(resetipv6["reset_dns"]); ngx.print(', "#ipv6-txt-clntdns");\
  changeButton("#ipv6-btn-advmangflag", ');  ngx.print(resetipv6["reset_advmanagedcall"]); ngx.print(', "#ipv6-txt-advmangflag");\
  changeButton("#ipv6-btn-advconfflag", ');  ngx.print(resetipv6["reset_advotherconfigflag"]); ngx.print(', "#ipv6-txt-advconfflag");\
\
  $("#ipv6-txt-dfltlifetime").val("');  ngx.print(resetipv6["reset_advdefaultlifetime"]); ngx.print('");\
  $("#ipv6-txt-advlnkmtu").val("');  ngx.print(resetipv6["reset_advlinkmtu"]); ngx.print('");\
  $("#ipv6-txt-maxrtradvint").val("');  ngx.print(resetipv6["reset_maxrtradvinterval"]); ngx.print('");\
  $("#ipv6-txt-minrtradvint").val("');  ngx.print(resetipv6["reset_minrtradvinterval"]); ngx.print('");\
});\
</script>\
\
'); 