--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local triesbeforemsg = 3
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local password_charachters = require("password_charachters")
local post_helper = require("web.post_helper")
local spl_char = password_charachters.spl_char
local std_upper_char = password_charachters.std_upper_char
local std_lower_char = password_charachters.std_lower_char
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "PasswordPage", "password")
local redirectPage = "/"
if post_helper.getVariantValue(variantHelper, "sessionLogout") then
  redirectPage = "/login.lp"
end

local function getFirmwareVersion()
  local firmwareVersion = proxy.get("rpc.system.fwupgrade.activeversion") or proxy.get("rpc.system.SoftwareVersion") or {}
  return firmwareVersion[1] and firmwareVersion[1].value or ""
end

local changepassword = T"Change password"
if post_helper.getVariantValue(variantHelper, "passwordFieldName") then
  changepassword = T"Profile Settings"
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "PasswordChanged" then
  local result = content_helper.getMatchedContent("uci.web.user.", {name = ngx.ctx.session:getusername()})
  if result and #result > 0 then
    proxy.set(result[1].path .. "password_changed", "1")
    if post_helper.getVariantValue(variantHelper, "DefaultAdminPassword") then
      proxy.set(result[1].path .. "default_password", "false")
    end
    if proxy.set(result[1].path .. "password_reminder", "0") then
      proxy.apply()
    end
  end
  if post_helper.getVariantValue(variantHelper, "sessionLogout") then
    ngx.ctx.session:logout()
    ngx.redirect("/")
  end
  ngx.exit(ngx.HTTP_OK)
end

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  nsplogo = "uci.web.uiconfig.@uidefault.nsplogo",
  timestamp = "uci.version.version.@version[0].timestamp"
}
content_helper.getExactContent(cui)
local passwordlength = proxy.get("uci.env.var.passwordlength")
passwordlength = passwordlength and passwordlength[1].value ~= "" and passwordlength[1].value or "12"

local year = cui.timestamp
local current_year = (string.sub(year, 1, 4))
--Start for legacy migration: GUI username/password [NG-48489]
local users = content_helper.getMatchedContent("uci.web.user.")
local userNames = ""
local legacySalts = ""

local logo_class = cui["nsplogo"]:match("logo%-(.+)%.") or ""
local stylesheet = cui["nsplogo"]:match("internode") and "/css/internode.css" or "/css/gw.css"

for _, user in ipairs(users) do
  if user.legacy_salt ~= "" then
    userNames = userNames .. user.name ..","
    legacySalts = legacySalts .. user.legacy_salt .. ","
  end
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().resetLegacySalt then
  --As the legacy user password has changed, to remove the legacy label,i.e., option legacy_salt.
  local user = content_helper.getMatchedContent("uci.web.user.", {name = ngx.ctx.session:getusername()})
  if user and #user > 0 then
    user = user[1]
    proxy.set(user.path .. "legacy_salt", "")
    proxy.apply()
  end
end
--End for legacy migration: GUI username/password [NG-48489]

local function createPwdLabel(desc)
  local html = {
    string.format([[
      <div class="control-group">
        <label>
          <div class="label-icon">
            <i class="icon-large"></i>
          </div>
        </label>
        %s
      </div>
      ]], desc),
  }
  return html
end

  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
<head>\
  <meta charset="UTF-8">\
  <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
  <link href="');  ngx.print( stylesheet ); ngx.print('" rel="stylesheet">\
  ');  if post_helper.getVariantValue(variantHelper, "logoStyleCss") then   ngx.print('\
    <link href="/css/responsive.css" rel="stylesheet">\
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
      @media screen and (max-width: 1200px){\
        .pstrength0 {width: 10px;}\
        .pstrength1 {width: 55px;}\
        .pstrength2 {width: 100px;}\
        .pstrength3 {width: 140px;}\
        .pstrength4 {width: 185px;}\
      }\
      @media screen and (min-width: 1200px){\
        .pstrength0 {width: 10px;}\
        .pstrength1 {width: 55px;}\
        .pstrength2 {width: 100px;}\
        .pstrength3 {width: 140px;}\
        .pstrength4 {width: 185px;}\
      }\
    </style>\
  ');  end   ngx.print('\
  <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
  <script src="/js/main-min.js?');  ngx.print(getFirmwareVersion()); ngx.print('" ></script>\
  <script src="/js/jquery-eval-patch.js"></script>\
  <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
  <script src="/js/srp-min.js" ></script>\
  <title>');  ngx.print( T"Change password" ); ngx.print('</title>\
\
</head>\
<body>\
  <div class="container">\
    ');  local logoClass = post_helper.getVariantValue(variantHelper, "logo") and '/img/' .. cui.nsplogo or  "/img/logo.gif"
    if post_helper.getVariantValue(variantHelper, "logoStyleCss") then   ngx.print('\
      <div class="logo-technicolor"><img src="/img/logo.png"></div>\
    ');  else   ngx.print('\
      <div class="logo-technicolor ');  ngx.print(logo_class); ngx.print('"><a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank"><img src="');  ngx.print( logoClass ); ngx.print('"></a></div>\
    ');  end   ngx.print('\
    <div class="row">\
      <div class="offset4 span4">\
        <div class="login">\
          <form class="form-horizontal">\
            ');  local logostyle = post_helper.getVariantValue(variantHelper, "logoStyleCss") and "min-width:auto" or ""  ngx.print('\
            <fieldset style = "');  ngx.print( logostyle ); ngx.print('" >\
              <h2>');  ngx.print( T"Change password" ); ngx.print('</h2>\
              ');  if post_helper.getVariantValue(variantHelper, "passwordStrength") then   ngx.print('\
                 <div id="erroruserpass" class="alert alert-error hide">\
                   <strong>');  ngx.print( T"Passwords do not match" ); ngx.print('</strong>\
                 </div>\
                 <div id="erroruserpass_2" class="alert alert-error hide">\
                   <strong>');  ngx.print( string.format(T"Password must contain at least %d alphanumeric characters including both upper and lower case letters, at least one number and at least one special character",passwordlength) ); ngx.print('</strong>\
                 </div>\
                 <div id="erroruserpass_3" class="alert alert-error hide">\
                   <strong>');  ngx.print( T"Provide a password to prevent unauthorized access to the gateway" ); ngx.print('</strong>\
                 </div>\
                 <div id="erroruserpass_4" class="alert alert-error hide">\
                   <strong>');  ngx.print( T"Old password is incorrect" ); ngx.print('</strong>\
                 </div>\
              ');  else   ngx.print('\
                 <div id="erroruserpass" class="alert alert-error hide">\
                   <strong>');  ngx.print( T"Invalid Password" ); ngx.print('</strong>\
                 </div>\
              ');  end   ngx.print('\
\
            ');  ngx.print(createPwdLabel(T"Your Username"));   ngx.print('\
               <div class="control-group">\
                  <label for="srp_username"><div style="margin-right:14px" class="label-icon">\
                  <i class="icon-user icon-large"></i>\
               </div>\
            </label>\
            ');  ngx.print(ngx.ctx.session:getusername());   ngx.print('\
\
            ');  ngx.print( createPwdLabel(T"Your old password") ); ngx.print('\
            <div class="control-group">\
                <label for="srp_password"><div class="label-icon">\
                    <i class="icon-lock icon-large"></i>\
                </div></label>\
                <input class="span3" type="password" id="srp_password" autofocus><br><br>\
            </div>\
            <!-- HIDE WARNING - NOT USED IN DEFAULT CUSTO\
            <div id="defaultpassword" class="alert alert-info hide">\
                ');  ngx.print( T"If you haven't changed it, the default password can be found on the sticker under your gateway (it's called <strong>\"access code\"</strong>)" ); ngx.print('\
            </div>\
            -->\
            ');  ngx.print( createPwdLabel(T"Your new password") ); ngx.print('\
            <div class="control-group">\
                <label for="srp_password_new_1"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                ');  if post_helper.getVariantValue(variantHelper, "passwordStrength") then   ngx.print('\
                   <input class="span3" type="password" id="srp_password_new_1" onkeyup="passwordCheck(this.value)"><br>\
                   <label for="Strength"></label>\
                   <div id="Password_Strength" class="span3"></div><br>\
                ');  else   ngx.print('\
                   <input class="span3" type="password" id="srp_password_new_1"><br><br>\
                ');  end   ngx.print('\
\
            </div>\
            ');  ngx.print( createPwdLabel(T"Repeat new password") ); ngx.print('\
            <div class="control-group">\
                <label for="srp_password_new_2"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                <input class="span3" type="password" id="srp_password_new_2"><br><br>\
            </div>\
            <div class="pull-right">\
                <a href="/" class="btn btn-primary btn-large">');  ngx.print( T"Cancel" ); ngx.print('</a>\
                &nbsp;\
                <div id="change-my-pass" class="btn btn-primary btn-large">');  ngx.print( T"Change password" ); ngx.print('</div>\
            </div>\
          </fieldset>\
        </form>\
      </div>\
      </div>\
    </div>\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
  </div>\
<script>\
  var spl_char = ');  ngx.print(spl_char); ngx.print(';\
  var std_lower_char = ');  ngx.print(std_lower_char); ngx.print(';\
  var std_upper_char = ');  ngx.print(std_upper_char); ngx.print(';\
  var triesbeforemsg = ');  ngx.print( triesbeforemsg ); ngx.print(';\
  var changePassword = \'');  ngx.print( T"Change password" ); ngx.print('\';\
  var passwordStrength  = ');  ngx.print( post_helper.getVariantValue(variantHelper, "passwordStrength")); ngx.print(';\
  var updating = \'');  ngx.print( T"Updating" ); ngx.print('\'\
  var username = \'');  ngx.print( ngx.ctx.session:getusername() ); ngx.print('\';\
  var legacySalts = "');  ngx.print( legacySalts ); ngx.print('";\
  var userNames = "');  ngx.print( userNames ); ngx.print('";\
  var passwordlength = "');  ngx.print( passwordlength ); ngx.print('";\
  var redirectPage = "');  ngx.print( redirectPage ); ngx.print('";\
</script>\
<script src="/js/password.js"></script>\
</body>\
</html>\
'); 