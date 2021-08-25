--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local web = require("web.web")
local telstra_helper = require("telstra_helper")
local symbolv1 = telstra_helper.symbolnamev1

local bridged = require("bridgedmode_helper")
local session = ngx.ctx.session
local role = session:getrole()
local storage_helper = require("storage_helper")

local assistance = require("web.assistance")
local assistant = assistance.getAssistant("remote")

-- this is to assist opening modal directly from the basic view
-- the path of modal to be opened will be stored in session and will be retrieved back by gateway.lp later
local getargs = ngx.req.get_uri_args()
if getargs and getargs.openmodal then
  storage_helper.store("openmodal",getargs.openmodal)
  ngx.redirect("/gateway.lp")
end

local cui = {
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
    timestamp = "uci.version.version.@version[0].timestamp",
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
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <title>');  ngx.print( T(symbolv1) ); ngx.print('</title>\
  </head>\
\
<body>\
  <div class="feedback">\
\
  </div>\
    <div class="container">\
    <div class="row">\
      <div class="header span12">\
        <img src="/img/logo.gif" style="max-height:67.5px">\
        ');  
          local html = {}
        html[#html + 1] = [[<div class="pull-right">]]
        if not bridged.isBridgedMode() then
            html[#html + 1] = '<a href="home.lp" class="btn" id="basicview">'
            html[#html + 1] = T"Basic View"
            html[#html + 1] = '</a>'
        end
        if session:isdefaultuser() then
            --NG-8926:After Signing in on the advaned user page you should be redirected to the Advance GUI
            --the login.lp with parameter flag=adv will let the current page "/gateway.lp" be stored in session
            --Later after authentication, the UI will redirect to "/gateway.lp"
            html[#html + 1] = '<a href="login.lp?from=adv" class="btn" id="signin">'
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
                    <ul class="dropdown-menu pull-right">]]
            if session:getusername() ~= assistant:username() then
                html[#html + 1] = [[ <li><a tabindex="-1" href="/password.lp" id="changepass">]]
                html[#html + 1] = T"Change my password"
                html[#html + 1] = [[ </a></li><li class="divider"></li> ]]
            end
            html[#html + 1] = [[ <li><a tabindex="-1" href="/" id="signout"> ]]
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
    <div id="waiting" class="loading hide"><img src="/img/spinner.gif" /></div>\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
  </div>\
  <script type = "text/javascript">\
    var role = "');  ngx.print(role); ngx.print('";\
    sessionStorage.setItem("userRole",role);\
  </script>\
</body>\
</html>\
');  
local modalname = storage_helper.retrieve("openmodal")
if modalname then
  storage_helper.store("openmodal", nil)
  ngx.print('\
<script type="text/javascript">\
    $(document).ready(function(){\
      $("div[class*=\'header-title\'][data-remote$=\'');  ngx.print(modalname); ngx.print('\'][data-toggle=\'modal\']").click();\
    });\
</script>\
');  end   ngx.print('\
'); 