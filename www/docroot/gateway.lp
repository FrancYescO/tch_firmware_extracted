--pretranslated: do not change this file
 
-- Enable localization
--NG-56120, NG-56248, NG-77544
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local web = require("web.web")
local session = ngx.ctx.session
local proxy = require("datamodel")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')
local message_helper = require("web.uimessage_helper")
local currentuser = session:getrole()
local json = require("dkjson")

local cui = {
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
    timestamp = "uci.version.version.@version[0].timestamp",
    schedule_reboot_get = "uci.system.scheduledreboot.enabled",
    system_time = "sys.time.CurrentLocalTime",
    sytem_reboot_time = "rpc.system.scheduledreboot",
}
content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year,1,4))

if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
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

function subtract2Minutes(myString)
  local time_get = myString:split(":")
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
  local alertMsg = T"Gateway is going to reboot within 2 minutes, Save your changes"
  local popupHeader = T"Reboot Schedule"
  local systemSplitsec = cui["sytem_reboot_time"]:split("Z")[1]:split("T")[2]
  local temp_time = cui["sytem_reboot_time"]:split("T")[1].."T"..subtract2Minutes(systemSplitsec).."Z"
  local systemtime_get = proxy.get("sys.time.CurrentLocalTime")
  systemtime_get = systemtime_get[1].value
  ngx.header.content_type = "application/json"
  ngx.print('{"systemTime":"'.. string.untaint(systemtime_get) ..'", "rebootTime":"'.. string.untaint(temp_time) ..'", "alertMsg":"'.. alertMsg ..'", "popupHeader":"'.. popupHeader ..'"}')
  ngx.exit(ngx.OK)
end
message_helper.popMessages()
  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( session:getCSRFtoken() ); ngx.print('">\
    <meta name="Advanced" content="');  ngx.print( cui.advanced ); ngx.print('">\
    <link href="/css/gw.css" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
	<link href="/css/TIM.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <title>');  ngx.print( T"Gateway" ); ngx.print('</title>\
  </head>\
\
<body>\
    ');  if web.isDemoBuild() then   ngx.print('\
    <div style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px;">Demo build, unofficial Technicolor SW, not suitable for deployment!</div>\
    ');  end   ngx.print('\
   <!-- Schedule Reboot message-->\
    ');  if cui.schedule_reboot_get == "1" then   ngx.print('\
    <div style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px;">A Reboot has been scheduled on ');  ngx.print(cui.sytem_reboot_time); ngx.print('</div>\
    ');  end  ngx.print('\
  <div class="feedback">\
\
  </div>\
    <div class="container">\
    <div class="row">\
      <div class="header span12" id="logo_mobiletab">\
	  <img class="timlogo" src="/img/TIM.png">\
        ');  
		local attri ={ select = {style ="width:auto; padding-top:7px; padding-bottom:7px; margin:auto; height: 36px"}}
        local html = {}

        html[#html + 1] = [[<div class="pull-right" style="padding-right:10px">]]
        if session:isdefaultuser() then
            html[#html + 1] = '<a href="login.lp" class="btn" id="signin">'
            html[#html + 1] = T"Sign in"
            html[#html + 1] = '</a>'
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
                html[#html + 1] = T"Profile Settings"
                html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
            end
            html[#html + 1] = [[ <li><a tabindex="-1" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]
        end
        html[#html + 1] = [[</div>]]

        html[#html + 1] = [[<div class="pull-right" style="padding-right:10px">]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language(),attri)
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
    ');  if not session:isdefaultuser() and not session:retrieve("password_reminder_shown") and session:getusername() ~= assistant:username() then
      local result = content_helper.getMatchedContent("uci.web.user.", {name = session.getusername()})
      if result and result[1].password_reminder ~= "0" then
        html = {}
        html[#html + 1] = '<div class="modal fade in" id="password_reminder">'
        html[#html + 1] = ui_helper.createHeader(T"Login Password")
        html[#html + 1] = '<div class="modal-body update">'
        html[#html + 1] = '<form class="form-horizontal" method="post" action="gateway.lp">'
        html[#html + 1] = ui_helper.createSimpleInputHidden("CSRFtoken", session:getCSRFtoken())
	html[#html + 1] = "<fieldset><legend>" .. T"Warning: current login password is the default one. It is strongly recommended to change it in order to enforce the security." .. "</legend>"
        html[#html + 1] = '<fieldset>'
        local attr = {radio = {style = "display: block"}}
        html[#html + 1] = ui_helper.createInputRadio("", "passwordchange", {{"now", T"Now"},{"remindlater", T"Remind me later"}},nil,attr)
        html[#html + 1] = '</fieldset>'
        html[#html + 1] = '</form>'
        html[#html + 1] = '</div>'
        html[#html + 1] = ui_helper.createFooter()
        html[#html + 1] = '</div>'
        ngx.print(html)  ngx.print('\
        <script>\
          $("#password_reminder").modal();\
          $("#save-config").click(function(){\
            var value = $("input[name=passwordchange]:checked").val();\
            if(value == "now"){\
               window.location = "/password.lp";\
            }else if(value == "remindlater"){\
               $("#password_reminder").modal(\'hide\');\
            }\
            return false;\
          });\
        </script>\
      ');  end
      session:store("password_reminder_shown", true)
    end  ngx.print('\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
  </div>\
</body>\
</html>\
<script>\
var current_role = \'');  ngx.print(currentuser); ngx.print('\';\
var processMsg=\'');  ngx.print(T"Processing"); ngx.print('\';\
var openMsg = \'');  ngx.print(T"Loading..."); ngx.print('\';\
var waitMsg = \'');  ngx.print(T"Please wait..."); ngx.print('\';\
var loginMsg =\'');  ngx.print(T"Login Expired. Reloading."); ngx.print('\';\
var okButton = \'');  ngx.print(T"Ok"); ngx.print('\';\
var cancelButton = \'');  ngx.print(T"Cancel"); ngx.print('\';\
var poperrorMsg = \'');  ngx.print(T"Same site cannot be added for multiple times"); ngx.print('\';\
var errorMsg = \'');  ngx.print(T"Please enter the valid URL"); ngx.print('\';\
\
if(window.sessionStorage.getItem("current_role") == null && current_role != "guest"){\
  window.sessionStorage.setItem("current_role", current_role);\
}\
\
function httpErrorMessage(err){\
    switch(err.status){\
        case 500:\
            erromsg=\'');  ngx.print(T"Internal Server Error occured, please contact administrator"); ngx.print('\'\
            break;\
        case 404:\
            erromsg=\'');  ngx.print(T"The requested file is not found! Please try again after some time"); ngx.print('\'\
            break;\
        case 503:\
            erromsg=\'');  ngx.print(T"The server is currently unavailable, Please try again after some time"); ngx.print('\'\
            break;\
        case 408:\
            erromsg=\'');  ngx.print(T"The server timed out waiting for the request"); ngx.print('\'\
            break;\
        default:\
             erromsg=\'');  ngx.print(T"The request could not be performed due to some error"); ngx.print('\'\
    }\
    window.setTimeout(function(){\
      erromsg = \'<div style="margin-left:35%;margin-top:9%;"><span class="alert-error">\'+erromsg+\'</span></div>\';\
      var ht = $(\'.modal-body\').height();\
      ht = toString(ht).match(/\\d+/) > 230 ? ht:230;\
      $(\'.modal-body\').height(ht);\
      var tab = $(\'.modal-body ul\').html();\
      if(tab != undefined)\
        erromsg = \'<ul class="nav nav-tabs">\' + tab + \'</ul>\' + erromsg;\
      $(\'.modal-body\').html(erromsg);\
    },400);\
}\
</script>\
'); 