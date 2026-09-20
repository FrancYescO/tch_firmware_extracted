--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local web = require("web.web")
--Check for logo change
local lfs = require("lfs")
local imgpath = "/img/"
if lfs.attributes("/www/docroot/img/custom/logo.gif", "mode") == "file" then
  imgpath = "/img/custom/"
end

local session = ngx.ctx.session

local proxy = require("datamodel")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')

TIMERJS = 5000


local args = ngx.req.get_uri_args()
local modal2load = session:retrieve("modal2load")
session:store("modal2load",nil)
if session:isdefaultuser() then
  session:store("first",nil)
end
local laterpassword = session:retrieve("first") 
local format = string.format
function split(x, sep)
        local sep, fields = sep or ":", {}
        local pattern = format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end
local cui = {
	product_name = "uci.env.var.prod_friendly_name",
	version = "uci.version.version.@version[0].version",
	nsplink = "uci.web.uiconfig.@uidefault.nsplink",
	advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	versionmask = "uci.version.version.@version[0].mask",
	timestamp = "uci.version.version.@version[0].timestamp",
}
content_helper.getExactContent(cui)

local year= cui.timestamp
local current_year = (string.sub(year,1,4))

local version = ""
local tmpsplit = split(cui.version, "-")
if #tmpsplit > 1 then
   version = format("%s-%s",tmpsplit[1],tmpsplit[2])
end
         
local proxy = require("datamodel")
if not session:isdefaultuser() then
  local first = format("%s",proxy.get("uci.env.custovar.first")[1].value)
  
  local result = content_helper.getMatchedContent("uci.web.user.", {name = session:getusername()})

    if result and #result > 0 and first and first == "1" and laterpassword ~= "later" then
      local reminder = format("%s",proxy.get(result[1].path .. "password_reminder")[1].value)
    	if reminder == "1" then
        ngx.redirect("/password.lp");
      end
    elseif first and first == "0" then
    	local reminder = format("%s",proxy.get(result[1].path .. "password_reminder")[1].value)
    	if reminder == "1" then
    	    	if proxy.set(result[1].path .. "password_reminder", "0") then
    	        	proxy.apply()
    	      	end
    	end
    end
end

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
<!DOCTYPE HTML>',
string.format('<html lang="%s">', gettext.language()),'\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="', ngx.ctx.session:getCSRFtoken() ,'">\
    <meta name="Advanced" content="', cui.advanced, '">\
    <link href="/css/gw.css" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
    <link href="/css/relf.css" rel="stylesheet">\
    <link href="/css/color.css" rel="stylesheet">\
    <link href="/css/loader.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <title>', T"Gateway", '</title>\
  <script type=\'text/javascript\'>\
    var status_check=0;\
    var L2_check;\
    var L3_check;\
    var WS_check;\
    function PopupBGRemove(){\
      $(".popUpBG").remove();\
      $("html, body").css({"overflow": "auto","height": "auto"});\
    }\
    function PopupBG(){\
       $("body").append(\'<div class="popUpBG"></div>\');\
       $("html, body").css({"overflow": "hidden","height": "1000%"});\
    }\
    $(function() {');
      	if modal2load then
ngx.print('\
          var m = $(\'<div class="modal fade"></div>\');\
          m.appendTo("body");\
          tch.loadModal("/modals/', modal2load, '", "", function() {\
              m.modal();\
          });');
      	end
ngx.print('\
    	PopupBGRemove();\
           $( document ).ajaxComplete(function( event, xhr, settings ) {\
              var action = 0;\
              var type = 0;\
              if (settings.data){\
                  if ((settings.data.indexOf("action=AJAX-GET") > -1)\
                      ||(settings.data.indexOf("action=system") > -1)\
                      ||(settings.data.indexOf("action=upgradefw") > -1)\
                  )action = 1;\
              } \
              if ((settings.url.indexOf("modal") > -1)\
                &&(action == 0)\
                &&(settings.url.indexOf("relf") == -1)\
                &&(settings.url.indexOf("check=1") == -1)\
                &&(settings.url.indexOf("upgrade") == -1)\
                ){\
                window.setTimeout(function(){\
                  $("[data-dismiss=\'modal\'], .modal-backdrop, #close-config.btn.btn-primary.btn-large").click(function(){PopupBGRemove();PopupBG();});\
\
                  //PopupBGRemove();\
                  if (status_check){clearTimeout(status_check)};\
                  if (L2_check){clearTimeout(L2_check)};\
                  if (L3_check){clearTimeout(L3_check)};\
                  if (WS_check){clearTimeout(WS_check)};\
                 },500);\
                \
                \
              }\
              \
           });\
\
    });\
  </script>\
  </head>\
\
<body>\
<div class="popUpBG"></div>'); 
    	if web.isDemoBuild() then
		local versioncusto = format("%s",proxy.get("uci.versioncusto.override.fwversion_suffix")[1].value)
		ngx.print('\<div style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:120%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px;">DEMO build, unofficial Technicolor SW, not suitable for deployment! <br/>Version: ', version, versioncusto, '</div>');
	end
ngx.print('\
  <div class="feedback">\
\
  </div>\
    <div class="container">\
    <div class="row">\
      <div class="header span12">\
        <a href="', cui.nsplink, '" target="_blank"><img class="logo" src="', imgpath, 'logo.gif"></a>');        
        local html = {}

        html[#html + 1] = [[<div class="pull-right">]]
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

        ngx.print(html, '\
      </div>\
    </div>\
    <div class="row">');
        local lp = require("web.lp")
        local cards = require("cards")
        for _,v in pairs(cards.cards()) do
          lp.include(v)
        end
ngx.print('\
    </div>\
    <div class="row">\
		<div class="copyright span12">\
			<p>&copy; Technicolor ',current_year, '</p>\
			<p>', format(T"Software Version: %s",version), '</p>\
		</div>\
	</div>\
  </div>\
</body>\
</html>\
<script>\
var processMsg=\'', T"Processing", '\';\
var openMsg = \'', T"Loading...", '\';\
var waitMsg = \'', T"Please wait...", '\';\
var loginMsg =\'', T"Login Expired. Reloading.", '\';\
var okButton = \'', T"Ok", '\';\
var cancelButton = \'', T"Cancel", '\';\
function httpErrorMessage(err){\
    switch(err.status){\
        case 500:\
            erromsg=\'', T"Internal Server Error occured", '\'\
            break;\
        case 404:\
            erromsg=\'', T"The requested file is not found! Please try again after some time", '\'\
            break;\
        case 503:\
            erromsg=\'', T"The server is currently unavailable, Please try again after some time", '\'\
            break;\
        case 408:\
            erromsg=\'', T"The server timed out waiting for the request",'\'\
            break;\
        default:\
             erromsg=\'', T"The request could not be performed due to some error", '\'\
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