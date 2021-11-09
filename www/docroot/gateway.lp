--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local web = require("web.web")
local session = ngx.ctx.session
local role = session:getrole()
local proxy = require("datamodel")
local bridged = require("bridgedmode_helper")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')
local message_helper = require("web.uimessage_helper")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "GatewayPage", "gateway")
local currentuser = session:getrole()
local json = require("dkjson")
local showSignInButton = post_helper.getVariantValue(variantHelper, "showSignInButton")

local changeMyPwd = T"Change my password"
local changePwd = T"Change Password"
if post_helper.getVariantValue(variantHelper, "profileSettings") then
  changeMyPwd = T"Profile Settings"
end
if post_helper.getVariantValue(variantHelper, "accessKey") then
  changePwd = T"Change Access Key"
end

local cui = {
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  nsplogo = "uci.web.uiconfig.@uidefault.nsplogo",
  advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
  timestamp = "uci.version.version.@version[0].timestamp",
  schedule_reboot_get = "uci.system.scheduledreboot.enabled",
  system_time = "sys.time.CurrentLocalTime",
  sytem_reboot_time = "rpc.system.scheduledreboot",
  wizard_accessed = "uci.system.system.@system[0].wizard_accessed"
}
content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year,1,4))

local logo_class =  post_helper.getVariantValue(variantHelper, "nspLogo") and (cui["nsplogo"]:match("(.+)%.") and string.format('class="%s"', cui["nsplogo"]:match("(.+)%.")) or "") or ""
local stylesheet = cui["nsplogo"]:match("internode") and "/css/internode.css" or "/css/gw.css"

if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  if not post_helper.getVariantValue(variantHelper, "passwordReminder") then
    if post_args.passwordchange == "dontremind" then
      local result = content_helper.getMatchedContent("uci.web.user.", {name = session:getusername()})
      if result and #result > 0 then
        if proxy.set(result[1].path .. "password_reminder", "0") then
          proxy.apply()
        end
      end
    end
  end
  if post_args.do_signout then
    session:logout()
    -- Now we redirect to / until we find a better solution
    -- Otherwise, the current page might be rendered while the default user is not allowed to see it
    -- since the access was checked for the user "before" logging out
    -- TODO: find a more elegant solution, in session module?
    ngx.redirect("/");
  end
end

function string:split( inSplitPattern, outResults )
  if not outResults then
    outResults = { }
  end
  local theStart = 1
  local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  while theSplitStart do
    table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
    theStart = theSplitEnd + 1
    theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  end
    table.insert( outResults, string.sub( self, theStart ) )
  return outResults
end

local function subtract2Minutes(myString)
  local time_get = myString:split(":")
  local time_split_get = ""
  if((time_get[2] == "00") or (time_get[2] == "01"))then
    time_get[2] = 60+time_get[2]
    if((time_get[1] == "00"))then
      time_get[1]="23"
    elseif(time_get[1] == "01")then
      time_get[1] = "00"
    else
      time_get[1] = time_get[1]-01
    end
  end

  time_get[2] = time_get[2]-02
  time_get[1] = string.format("%02d", time_get[1])
  time_get[2] = string.format("%02d", time_get[2])
  if time_get[3] == nil then
    time_split_get = time_get[1] ..":".. time_get[2]
  else
    time_split_get = time_get[1] ..":".. time_get[2]..":"..time_get[3]
  end
  return time_split_get
end

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().getSessionStatus == "true" then
  ngx.header.content_type = "application/json"
  local role = session:getrole()
  ngx.print(json.encode({current_role = role}))
  ngx.exit(ngx.OK)
end

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "scheduleReboot" then
  local systemSplitsec = cui["sytem_reboot_time"]:split("Z")[1]:split("T")[2]
  local temp_time = cui["sytem_reboot_time"]:split("T")[1].."T"..subtract2Minutes(systemSplitsec).."Z"
  local systemtime_get = proxy.get("sys.time.CurrentLocalTime")
  systemtime_get = systemtime_get[1].value
  ngx.header.content_type = "application/json"
  local alertMsg = T"Gateway is going to reboot within 2 minutes, Save your changes"
  local popupHeader = T"Reboot Schedule"
  ngx.print('{"systemTime":"'.. string.untaint(systemtime_get) ..'", "rebootTime":"'.. string.untaint(temp_time) ..'", "alertMsg":"'..alertMsg ..'", "popupHeader":"'.. popupHeader ..'"}')
  ngx.exit(ngx.OK)
end
message_helper.popMessages()
  ngx.print('\
\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( session:getCSRFtoken() ); ngx.print('">\
    <meta name="Advanced" content="');  ngx.print( cui.advanced ); ngx.print('">\
    <link href="');  ngx.print( stylesheet ); ngx.print('" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js"></script>\
    <script src="/js/chart-min.js"></script>\
    <script src="/js/jquery-eval-patch.js"></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
\
    ');  if post_helper.getVariantValue(variantHelper, "textAlignment") then   ngx.print('\
      <style>\
             @media screen and (max-width: 1200px) and (min-width: 1000px){\
               .smallcard .content {font-size: 97%;}\
               .smallcard .subinfos {font-size: 93%;}\
               .smallcard .simple-desc {inline-size: auto;}\
             }\
             @media screen and (max-width: 990px) and (min-width: 767px){\
               .smallcard .content {font-size: 77%;}\
               .smallcard .ethspeedsVal {font-size: 90%;}\
               .smallcard .header #Bridge_ETH_port_4_tab {font-size: 80%;}\
               .smallcard .subinfos {font-size: 100%;}\
               .smallcard .simple-desc {inline-size: auto;}\
             }\
             @media screen and (max-width: 765px) and (min-width: 260px){\
               .smallcard .ethspeedsVal {line-height: 15px;}\
             }\
      </style>\
    ');  end   ngx.print('\
\
    <title>');  ngx.print( T"Gateway" ); ngx.print('</title>\
  </head>\
\
<body>\
    ');  if web.isDemoBuild() then   ngx.print('\
    <div style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px;">Demo build, unofficial Technicolor SW, not suitable for deployment!</div>\
    ');  end   ngx.print('\
   <!-- Schedule Reboot message-->\
    ');  if post_helper.isFeatureEnabled("schedulereboot", role) and cui.schedule_reboot_get == "1" then   ngx.print('\
      <div style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px;">A Reboot has been scheduled on ');  ngx.print(cui.sytem_reboot_time); ngx.print('</div>\
    ');  end  ngx.print('\
  <div class="feedback">\
\
  </div>\
    <div class="container">\
    <div class="row">\
      <div class="header span12" id="logo_mobiletab">\
        ');  local logoClass = post_helper.getVariantValue(variantHelper, "logo") and "/img/logo.png" or  '/img/' .. cui.nsplogo
        if post_helper.getVariantValue(variantHelper, "loginStyleCSS") then   ngx.print('\
          <img class="logo" src="/img/logo.png">\
        ');  else   ngx.print('\
          ');  if post_helper.getVariantValue(variantHelper, "nspLink") then   ngx.print('\
            <a href = "');  ngx.print( cui.nsplink ); ngx.print('" target = "_blank"><img src = "');  ngx.print( logoClass ); ngx.print('" style="max-height:67.5px" ');  ngx.print(logo_class ); ngx.print(' ></a>\
          ');  else   ngx.print('\
            <img src = "');  ngx.print( logoClass ); ngx.print('" style="max-height:67.5px" ');  ngx.print(logo_class ); ngx.print(' >\
          ');  end   ngx.print('\
        ');  end   ngx.print('\
        ');  
        local attri ={ select = {style ="width:auto; padding-top:7px; padding-bottom:7px; margin:auto; height: 36px"}}
        local html = {}

        html[#html + 1] = [[<div class="pull-right" style="padding-right:10px">]]
        if not bridged.isBridgedMode() and session:hasAccess("/modals/wizard-modal.lp") then
          html[#html + 1] = '<div class="btn" id="wizard-btn" data-toggle="modal" data-remote="modals/wizard-modal.lp">' .. T"Setup Wizard" .. '</div>'
        end
        if session:isdefaultuser() then
          if showSignInButton then
            html[#html + 1] = '<a href="login.lp" class="btn" id="signin">'
            html[#html + 1] = T"Sign in"
            html[#html + 1] = '</a>'
          else
            html[#html + 1] = '<a href="https://fiber.google.com/myfiber/" class="btn" id="signin">'
            html[#html + 1] = T"My Fiber"
            html[#html + 1] = '</a>'
            html[#html + 1] = '<a href="https://fiber.google.com/support/" class="btn" id="signin">'
            html[#html + 1] = T"Customer Support"
            html[#html + 1] = '</a>'
          end
        else
            html[#html + 1] = [[          <div class="btn-group" id="logged">
                    <button class="btn"> ]]
            html[#html + 1] = session:getusername()
            html[#html + 1] = [[ </button>
                    <button class="btn dropdown-toggle" data-toggle="dropdown">
                      <span class="caret"></span>
                    </button>
                    <ul class="dropdown-menu pull-right"> ]]
            if session:getusername() ~= assistant:username() then
                html[#html + 1] = [[ <li><a tabindex="-1" href="/password.lp" id="changepass"> ]]
                html[#html + 1] = changeMyPwd
                html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
            end
            html[#html + 1] = [[ <li><a tabindex="-1" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]
        end
        html[#html + 1] = [[</div>]]

        html[#html + 1] = [[<div class="pull-right" style="padding-right:10px" >]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language(), attri)
        html[#html + 1] = [[</div>]]

        ngx.print(html)
          ngx.print('\
      </div>\
    </div>\
    <div class="row">\
      ');  
        local lp = require("web.lp")
        local cards = require("cards")
        for _,v in pairs(cards.cards()) do
          lp.include(v)
        end
        ngx.print('\
    </div>\
    ');  
      local lp = require("web.lp")
      lp.setpath("/www/docroot/")
      lp.include("change-access-key.lp")
      ngx.print('\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
  </div>\
\
<script type="text/javascript">\
');  if post_helper.isFeatureEnabled("langAuto", role) then   ngx.print('\
  $(\'#webui_language\').prepend(\'<option value="auto">Auto</option>\');\
');  end   ngx.print('\
var wizard  = \'');  ngx.print(post_helper.getVariantValue(variantHelper, "wizard")); ngx.print('\'\
var wizard_accessed = \'');  ngx.print(cui.wizard_accessed); ngx.print('\'\
var current_role = \'');  ngx.print(currentuser); ngx.print('\';\
var processMsg=\'');  ngx.print(T"Processing"); ngx.print('\';\
var openMsg = \'');  ngx.print(T"Loading..."); ngx.print('\';\
var waitMsg = \'');  ngx.print(T"Please wait..."); ngx.print('\';\
var loginMsg =\'');  ngx.print(T"Login Expired. Reloading."); ngx.print('\';\
var okButton = \'');  ngx.print(T"Ok"); ngx.print('\';\
var cancelButton = \'');  ngx.print(T"Cancel"); ngx.print('\';\
var poperrorMsg = \'');  ngx.print(T"Same site cannot be added for multiple times"); ngx.print('\';\
var errorMsg = \'');  ngx.print(T"Please enter the valid URL"); ngx.print('\';\
var errorGroup = new Array("');  ngx.print(T"Internal Server Error occured, please contact administrator"); ngx.print('", "');  ngx.print(T"The requested file is not found! Please try again after some time"); ngx.print('", "');  ngx.print(T"The server is currently unavailable, Please try again after some time"); ngx.print('", "');  ngx.print(T"The server timed out waiting for the request"); ngx.print('", "');  ngx.print(T"The request could not be performed due to some error"); ngx.print('");\
</script>\
<script src="/js/gateway.js"></script>\
</body>\
</html>\
'); 