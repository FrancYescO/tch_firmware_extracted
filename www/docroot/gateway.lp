--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local web = require("web.web")

local bridged = require("bridgedmode_helper")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant("remote")
local currentuser = ngx.ctx.session:getrole()
local json = require("dkjson")

local cui = {
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    nsplogo = "uci.web.uiconfig.@uidefault.nsplogo",
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
    wizard_accessed = "uci.system.system.@system[0].wizard_accessed",
    timestamp = "uci.version.version.@version[0].timestamp",
}
content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year,1,4))

local logo_class = cui["nsplogo"]:match("(.+)%.")
if logo_class then
    logo_class = string.format('class="%s"',logo_class)
else
    logo_class = ""
end
local stylesheet = cui["nsplogo"]:match("internode") and "/css/internode.css" or "/css/gw.css"
stylesheet = stylesheet .."?".. cui.timestamp

if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  if post_args.do_signout then
    ngx.ctx.session:logout()
    -- Now we redirect to / until we find a better solution
    -- Otherwise, the current page might be rendered while the default user is not allowed to see it
    -- since the access was checked for the user "before" logging out
    -- TODO: find a more elegant solution, in session module?
    ngx.redirect("/");
  end
end

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().getSessionStatus == "true" then
  ngx.header.content_type = "application/json"
  local role = ngx.ctx.session:getrole()
  ngx.print(json.encode({current_role = role}))
  ngx.exit(ngx.OK)
end
  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <meta name="Advanced" content="');  ngx.print( cui.advanced ); ngx.print('">\
    <link href="');  ngx.print( stylesheet ); ngx.print('" rel="stylesheet">\
    <link href="/css/responsive.css?');  ngx.print(cui.timestamp); ngx.print('" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css?');  ngx.print(cui['timestamp']); ngx.print('"><![endif]-->\
    <script src="/js/main-min.js?');  ngx.print(cui.timestamp); ngx.print('" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js?');  ngx.print(cui.timestamp); ngx.print('"></script> <![endif]-->\
    <title>');  ngx.print( T"Gateway" ); ngx.print('</title>\
  </head>\
\
<body>\
    ');  if web.isDemoBuild() then   ngx.print('\
        <div style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px;">Demo build, unofficial Technicolor SW, not suitable for deployment!</div>\
    ');  end   ngx.print('\
  <div class="feedback">\
\
  </div>\
    <div class="container">\
    <div id="waiting" class="loading hide"><img src="/img/spinner.gif" /></div>\
    <div class="row">\
      <div class="header span12">\
        <a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank"><img src="');  ngx.print('/img/' .. cui.nsplogo ); ngx.print('" ');  ngx.print(logo_class ); ngx.print(' ></a>\
        ');  
        local session = ngx.ctx.session
        local html = {}

        html[#html + 1] = [[<div class="pull-right">]]
        if not bridged.isBridgedMode() then
            html[#html + 1] = '<div class="btn" id="wizard-btn" data-toggle="modal" data-remote="modals/wizard-modal.lp">' .. T"Setup Wizard" .. '</div>'
        end
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
            if assistant:username() ~= session:getusername() then
                html[#html + 1] = [[ <li><a tabindex="-1" href="/password.lp" id="changepass">]]
                html[#html + 1] = T"Change my password"
                html[#html + 1] = [[ </a></li><li class="divider"></li>]]
            end
            html[#html + 1] = [[<li><a tabindex="-1" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]
        end
        html[#html + 1] = [[</div>]]

        html[#html + 1] = [[<div class="pull-right">]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language())
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
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
  </div>\
</body>\
</html>\
');  if cui.wizard_accessed ~= "1" then  ngx.print('\
<script type="text/javascript">\
    $(document).ready(function(){\
      $("#wizard-btn").click();\
    });\
</script>\
');  end   ngx.print('\
<script>\
    $(document).on("click", "#cancel-config", function (a)\
    {\
      $(".loading").removeClass("hide");\
    });\
    $(document).on("click", ".span1 a.button.btn-primary.btn-close", function (a)\
    {\
      $(".loading").removeClass("hide");\
    });\
    $(document).on("click", "#close-config", function (a)\
    {\
      $(".loading").removeClass("hide");\
    });\
\
var current_role = \'');  ngx.print(currentuser); ngx.print('\';\
\
if(window.sessionStorage.getItem("current_role") == null && current_role != "guest"){\
  window.sessionStorage.setItem("current_role", current_role);\
}\
</script>\
\
'); 