--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local triesbeforemsg = 3
local content_helper = require("web.content_helper")
local proxy = require ("datamodel")
local format, find, sub = string.format, string.find, string.sub
local post_helper = require("web.post_helper")
local json = require("dkjson")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "LoginPage", "login")
local bridged = require("bridgedmode_helper")
local wanIntf = post_helper.getActiveInterface()
local assistance = require("web.assistance")
local uciAssistance = "uci.web.assistance."
local contentAssistance = content_helper.convertResultToObject(uciAssistance .. "@.", proxy.get(uciAssistance))
local timeout = contentAssistance[1].timeout
local secname = contentAssistance[1].paramindex
local assistant = assistance.getAssistant(secname)
local untaint = string.untaint

local hostURL = untaint(ngx.var.host)
local assistURL = assistant:URL()

local passwd_count_msg = format(T"You are trying to login with wrong password for %s times", '<span id="pwdCount"></span>')
local timer_msg = format(T"Please wait %s seconds to enter new password", '<span id="timerSec"></span>')

if post_helper.getVariantValue(variantHelper,"lastAccess") then
  if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "redirect" then
    local ipaddr = ""
    if ngx.req.get_uri_args().param == "system_reset" then
      ipaddr = proxy.get("uci.ucidefaults.interface.@lan_reset.ipaddr")[1].value
    else
      ipaddr = proxy.get("uci.network.interface.@lan.ipaddr")[1].value
    end
    ngx.header.content_type = "application/json"
    ngx.print(json.encode(ipaddr))
    ngx.exit(ngx.HTTP_OK)
  end

  local lastaccess = {
    user = "" ,
    time = "",
    clientIp = ""
  }

  local function writeState(lastAccess)
    local f = io.open("/etc/lastaccess", "w")
    if f then
      for key, value in pairs(lastAccess) do
        f:write(format("%s=%s\n", key, value))
      end
      f:close()
    end
  end

  if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "lastaccess" then
    lastaccess.user = ngx.ctx.session:getusername()
    lastaccess.clientIp = ngx.var.remote_addr
    lastaccess.time = os.date("%T", os.time())
    writeState(lastaccess)
  end
end

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  timestamp = "uci.version.version.@version[0].timestamp",
  nsplogo = "uci.web.uiconfig.@uidefault.nsplogo",
  firmware_version = "uci.version.version.@version[0].version",
  fwversion_prefix = "uci.versioncusto.override.fwversion_prefix",
  fwversion_suffix = "uci.versioncusto.override.fwversion_suffix",
  fwversion_override = "uci.versioncusto.override.fwversion_override"
}

local domain = {
  domianStatev4 = "uci.ddns.service.@myddns_ipv4.enabled",
  domainStatev6 = "uci.ddns.service.@myddns_ipv6.enabled",
  domainNamev4 = "uci.ddns.service.@myddns_ipv4.domain",
  domainNamev6 = "uci.ddns.service.@myddns_ipv6.domain"
}

content_helper.getExactContent(domain)
local isDomainURL = false

if domain.domianStatev4 == "1" or domain.domainStatev6 == "1" then
  if domain.domainNamev4:match(hostURL) or domain.domainNamev6:match(hostURL) then
    isDomainURL = true
  end
end

if post_helper.getVariantValue(variantHelper, "remoteAssistanceUserName") and (assistURL and assistURL:match(hostURL) or isDomainURL) then
  cui.defaultuser = "uci.web.uiconfig.@uidefault.defaultremoteuser"
end

content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year, 1, 4))

if cui.firmware_version then
  local version = cui.firmware_version
  cui.firmware_version = cui.fwversion_prefix .. sub(version, 1, find(version, "%-[^%-]*$") - 1) .. cui.fwversion_suffix
  if cui.fwversion_override then
    if cui.fwversion_override == "override1" then
      cui.firmware_version = cui.fwversion_prefix .. sub(version, 1, find(version, "%-") -1) .. cui.fwversion_suffix
    end
  end
end

local users = content_helper.getMatchedContent("uci.web.user.")
local userNames = ""
local legacySalts = ""
local httpi, httpi_wwan = "", ""
if not bridged.isBridgedMode() and post_helper.getVariantValue(variantHelper, "loginInternetStatus") then
  httpi = proxy.get("rpc.network.interface.@"..wanIntf..".up")[1].value
  httpi_wwan = proxy.get("rpc.network.interface.@wwan.up") and proxy.get("rpc.network.interface.@wwan.up")[1].value or ""
end

for _, user in ipairs(users) do
  if user.legacy_salt ~= "" then
    userNames = userNames .. user.name ..","
    legacySalts = legacySalts .. user.legacy_salt .. ","
  end
end

local stylesheet = ""
if post_helper.getVariantValue(variantHelper, "logo") then
  stylesheet = cui["nsplogo"]:match("internode") and "/css/internode.css" or "/css/gw.css"
else
  stylesheet = "/css/gw.css"
end

  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
<head>\
    <meta name = "viewport" content = "width = device-width, initial-scale = 1.0">\
    <meta charset = "UTF-8">\
    <meta name = "CSRFtoken" content = "');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <link href = "');  ngx.print( stylesheet ); ngx.print('" rel = "stylesheet">\
    <link href = "/css/responsive.css" rel = "stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src = "/js/main-min.js" ></script>\
    <script src="/js/jquery-eval-patch.js"></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <script src = "/js/srp-min.js" ></script>\
\
    ');  if post_helper.getVariantValue(variantHelper, "loginStyleCSS") then   ngx.print('\
     <style>\
                @media screen and (max-width: 979px) and (min-width: 768px){\
                        .span4 {width: 300px;}\
                }\
                @media screen and (max-width: 979px) and (min-width: 768px){\
                input.span3, textarea.span3, .uneditable-input.span3\
                        {width: 206px;}\
                }\
                @media screen and (max-width: 979px) and (min-width: 768px){\
                .offset4 {margin-left: 231px;}\
                }\
        </style>\
     ');  end   ngx.print('\
    <title>');  ngx.print( T"Login" ); ngx.print('</title>\
</head>\
<body>\
  <div class = "container">\
    ');  local logoClass = post_helper.getVariantValue(variantHelper, "logo") and '/img/' .. cui.nsplogo or  "/img/logo.gif"
    if post_helper.getVariantValue(variantHelper, "loginStyleCSS") then   ngx.print('\
      <div class = "logo-technicolor"><img class = "logo" src = "/img/logo.png"></div>\
    ');  else   ngx.print('\
      <div class = "logo-technicolor"><a href = "');  ngx.print( cui.nsplink ); ngx.print('" target = "_blank"><img src = "');  ngx.print(logoClass); ngx.print('"></a></div>\
    ');  end   ngx.print('\
    <div class = "row">\
      <div class = "offset4 span4">\
        <div class = "login" id = "login">\
        <form class = "form-horizontal">\
          <fieldset>\
             <h2>');  ngx.print( T"Sign in" ); ngx.print('</h2>\
             ');  if post_helper.getVariantValue(variantHelper,"loginInternetStatus") then
                  if httpi == '0' and httpi_wwan == '0' then   ngx.print('\
                    <div id = "httpi" class = "alert alert-error ">\
                      <strong>');  ngx.print( T"You don't have internet access at this time" ); ngx.print('</strong>\
                    </div>\
                  ');  end
             end   ngx.print('\
            <div id = "erroruserpass" class = "alert alert-error hide">\
               <strong>');  ngx.print( T"Invalid Username or Password" ); ngx.print('</strong>\
            </div>\
            <div class = "control-group">\
                <label for = "srp_username"><div class = "label-icon">\
                    <i class = "icon-user icon-large"></i>\
                </div></label>\
		');  if post_helper.getVariantValue(variantHelper, "remoteAssistanceUserName") and assistURL and assistURL:match(hostURL) then   ngx.print('\
		     <input class = "span3" type = "text" placeholder = "');  ngx.print( T"Your username" ); ngx.print('" id = "srp_username" value = "');  ngx.print( cui.defaultuser ); ngx.print('" autofocus><br><br>\
		');  else   ngx.print('\
                <input class = "span3" type = "text" placeholder = "');  ngx.print( T"Your username" ); ngx.print('" id = "srp_username" value = "');  ngx.print( cui.defaultuser ); ngx.print('" autofocus><br><br>\
		');  end   ngx.print('\
            </div>\
            <div class = "control-group">\
               <label for = "srp_password"><div class = "label-icon"><i class = "icon-lock icon-large"></i></div></label>\
               <input class = "span3" type = "password" placeholder = "');  ngx.print( T"Your password" ); ngx.print('" id = "srp_password" autocomplete = "new-password"><br><br>\
            </div>\
            <div style="text-align: right;"><input type="checkbox" id="showPassword" onclick="showPass()" style="position: relative;bottom: 4px;right: 4px;">');  ngx.print( T"Show Password" ); ngx.print('</div>\
            <!-- HIDE WARNING - NOT NOT USED IN DEFAULT CUSTO\
            <div id = "defaultpassword" class = "alert alert-info hide">\
                ');  ngx.print( T"If you haven't changed it, the default password can be found on the sticker under your gateway (it's called <strong>\"access code\"</strong>)" ); ngx.print('\
            </div>\
            -->\
            <div class = "pull-right" style="position:relative;top:10px;">\
                <a href = "/" class = "btn btn-primary btn-large">');  ngx.print( T"Cancel" ); ngx.print('</a>\
                &nbsp;\
                <div id = "sign-me-in" class = "btn btn-primary btn-large">');  ngx.print( T"Sign in" ); ngx.print('</div>\
            </div>\
            ');  if post_helper.getVariantValue(variantHelper, "forgotPassword") then   ngx.print('\
               <div id = "forgot-login-password">\
                 <a href = "#">');  ngx.print( T"Forgot Login Password" ); ngx.print('</a>\
               </div>\
            ');  end   ngx.print('\
          </fieldset>\
        </form>\
      </div>\
      ');  if post_helper.getVariantValue(variantHelper, "forgotPassword") then   ngx.print('\
        <div class = "login hide" id = "forgot-login">\
          <form class = "form-horizontal">\
            <fieldset>\
              <h2>');  ngx.print( T"Reset Password" ); ngx.print('</h2>\
              <div id = "erroruserpass1" class = "alert alert-error hide">\
                <strong>');  ngx.print( T"Invalid Password" ); ngx.print('</strong>\
              </div>\
              <div class = "control-group">\
                <label for = "srp_password1" class = "alert-info">');  ngx.print( T"Enter the default <strong>\"access code\"</strong>. This code is located on the label underneath your gateway." ); ngx.print('</label>\
                <label for = "srp_password1"><div class = "label-icon"><i class = "icon-lock icon-large"></i></div></label>\
                <input class = "span3" type = "password" placeholder = "');  ngx.print( T"Your password" ); ngx.print('" id = "srp_password1"><br><br>\
              </div>\
              <div class = "pull-right">\
                <a href = "/" class = "btn btn-primary btn-large">');  ngx.print( T"Cancel" ); ngx.print('</a>&nbsp;\
                <div id = "verify-password" class = "btn btn-primary btn-large">');  ngx.print( T"Verify" ); ngx.print('</div>\
              </div>\
            </fieldset>\
          </form>\
        </div>\
      ');  end   ngx.print('\
     </div>\
    </div>\
    ');  if post_helper.getVariantValue(variantHelper, "standardUserDetails") then   ngx.print('\
      <div class = "content span20" style = "width: 100%; text-align: center; margin-left: 10px;">\
         <p class = "subinfos">\
            <strong>\
               ');  ngx.print(T"The standard Username is: "); ngx.print( cui.defaultuser ); ngx.print('<br>\
               ');  ngx.print(T"The default Password is printed on the bottom of the MediaAccess Gateway (ACCESS KEY)."); ngx.print('<br>\
            </strong>\
         </p>\
      </div>\
    ');  end
    local firmwareVersion = post_helper.getVariantValue(variantHelper, "firmwareVersion") and cui.firmware_version or ""   ngx.print('\
    <div class = "row"><div class = "copyright span12"><p>');  ngx.print( firmwareVersion ); ngx.print('</p><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
  </div>\
  ');  if post_helper.getVariantValue(variantHelper, "loginFailureAttempt") then   ngx.print('\
    <div class = "modal-fade hide" id = "loginfailure" data-backdrop = "static" role = "dialog">\
      <div class = "popUp smallcard popUp-modal span4" style = "margin-top: -50px">\
        <div class = "header"><div data-toggle = "modal" class = "header-title pull-left"><p>Processing</p></div></div>\
         <div class = "modal-body no-padding">\
           <form class = "form-horizontal">\
             <div>\
               <label id = "wronguser-attempt" for = "inputPassword" class = "control-label wronguser-attempt">');  ngx.print(passwd_count_msg); ngx.print('<br/>');  ngx.print(timer_msg); ngx.print('</label>\
             </div>\
             <div id = "spinner" class = "spinner" align = "center">\
               <div class = "spinner3">\
                 <div class = "rect1" style = "background-color: rgb(92, 22, 96);"></div>\
                 <div class = "rect2" style = "background-color: rgb(92, 22, 96);"></div>\
                 <div class = "rect3" style = "background-color: rgb(92, 22, 96);"></div>\
                 <div class = "rect4" style = "background-color: rgb(92, 22, 96);"></div>\
                 <div class = "rect5" style = "background-color: rgb(92, 22, 96);"></div>\
               </div>\
             </div>\
           </form>\
         </div>\
       </div>\
     </div>\
   ');  end   ngx.print('\
<script>\
    var triesbeforemsg = ');  ngx.print( triesbeforemsg ); ngx.print(';\
    var verifying = \'');  ngx.print( T"Verifying" ); ngx.print('\';\
    var loginFailureAttempt = ');  ngx.print(post_helper.getVariantValue(variantHelper, "loginFailureAttempt") ); ngx.print(';\
    var forgotPassword = ');  ngx.print(post_helper.getVariantValue(variantHelper, "forgotPassword")); ngx.print('\
        var legacySalts = "');  ngx.print( legacySalts ); ngx.print('";\
        var userNames = "');  ngx.print( userNames ); ngx.print('";\
        var signIn = \'');  ngx.print( T"Sign in" ); ngx.print('\';\
        var lastAccess = ');  ngx.print(post_helper.getVariantValue(variantHelper, "lastAccess")); ngx.print(';\
        var loginFailureAttempt = ');  ngx.print(post_helper.getVariantValue(variantHelper, "loginFailureAttempt")); ngx.print(';\
   var verify = \'');  ngx.print( T"Verify" ); ngx.print('\';\
</script>\
<script src="/js/login.js"></script>\
</body>\
</html>\
'); 