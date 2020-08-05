--pretranslated: do not change this file

--[[
   ISP Page 
   A:David Relf
   E:david.relf@technicolor.com
   
   Page is to remove the ispconfig file from the location 
   /etc/ispconfig/tch_0000-ispconfig
   
   V1.0 - Initial version with Change control
   V1.1 - Add remove logo
   V1.2 - Add create ISP config for ppp details and ACS URL
]]
local format, match, sub= string.format, string.match, string.sub
local print= ngx.print
-- Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel") 

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
--Check for logo change
local lfs = require("lfs")
local logo_present = 0

function split(x, sep)
        local sep, fields = sep or ":", {}
        local pattern = format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

local cui = {
	version = "uci.version.version.@version[0].version",
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

local mapParams = {
  uci_wan_username = "uci.network.interface.@wan.username",
  uci_wan_password = "uci.network.interface.@wan.password",
  uci_cwmp_url     = "uci.cwmpd.cwmpd_config.acs_url",
}

local gVP = post_helper.getValidationPassword
local vNES = post_helper.validateNonEmptyString
local gOV = post_helper.getOptionalValidation
local gCV = post_helper.getConditionalValidation
local gS255 = post_helper.getValidateStringLengthInRange(1,255)


local function validatecwmpurl (value, postdata)
    local err,msg = gS255(value)
    
    if not err then
      return err,msg
    end

    if not(value:match("^http://") or value:match("^https://")) then  
		  return nil, T"Invalid ACS URL- URL must start with http:// or https://"
    end
  
    return true
end

                                                                       

local mapValid = {
  uci_wan_username = vNES,
  uci_wan_password = gVP(vNES),
  uci_cwmp_url     = validatecwmpurl,
}


local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)


if ngx.req.get_method() == "POST" and #helpmsg == 0 then
  local post_args = ngx.req.get_post_args()

   if post_args.action == "SAVE" and post_args.ispdelete == "1" then
         proxy.set("sys.ispconfig.Delete", "1")
   end
   if post_args.action == "SAVE" and post_args.logodelete == "1" then
         proxy.set("sys.ispconfig.LogoDelete", "1")
   end
   if post_args.action == "SAVE" and post_args.ispcreate == "1" then
         proxy.set("sys.ispconfig.CreateDef", format("pppuser=%s,ppppass=%s,acsurl=%s,",post_args["uci_wan_username"],post_args["uci_wan_password"],post_args["uci_cwmp_url"]:untaint()) )
   end
  
end

local imgpath = "/img/"
if lfs.attributes("/www/docroot/img/custom/logo.gif", "mode") == "file" then
  imgpath = "/img/custom/"
  logo_present = 1
end




local cui = {
    nsplink    = "uci.web.uiconfig.@uidefault.nsplink",
    advanced   = "uci.web.uiconfig.@uidefault.alwaysadvanced",
    version    = "uci.version.version.@version[0].version",
}
content_helper.getExactContent(cui)

local isp_content = {
      isp_present = "sys.ispconfig.Present",
}

content_helper.getExactContent(isp_content)

local version = ""
local tmpsplit = split(cui.version, "-")
if #tmpsplit > 1 then
   version = format("%s-%s",tmpsplit[1],tmpsplit[2])
end


local logovalue = "Disabled"
if logo_present ~= 0 then
   logovalue = "Enabled"
end

local ispvalue = "Disabled"
if isp_content["isp_present"] ~= "0" then
   ispvalue = "Enabled"
end

local state_map = {
    Disabled = T"No File Detected",
    Enabled = T"File Present",
}

local light_map = {
  Disabled = "0",
  Enabled = "1",
}

local isp_warning = {
    alert = {
        class = "alert-warning"
    },
}
ngx.print('\
<!DOCTYPE HTML>',
string.format('<html lang="%s">', gettext.language()),'\
  <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="', ngx.ctx.session:getCSRFtoken(), '">\
    <meta name="Advanced" content="', cui.advanced, '">\
    <link href="/css/gw.css" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
    <link href="/css/color.css" rel="stylesheet">\
    <link href="/css/relf.css" rel="stylesheet">\
    <link href="/css/httpi.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <title>', T"Gateway", '</title>\
  </head>\
<script type=\'text/javascript\'>\
\
\
function Popup(x){\
    var moveLeft = 10;\
    var moveRight = -390;\
    var moveDown = -50;\
    var header = \'', ui_helper.createCardHeader(T"Processing", "", "",""), '\';\
   $("body").append(\'<div class=\"popUpBG\"></div>\')\
   $("body").append(\'<div id="popUp" class="smallcard span3">\'+header+\'<div id="Poptxt" class="content"></div>\')\
   $("#Poptxt").html(x);\
   $d = $("#popUp");\
   var pagewidth = $("body").width();\
   var thiswidth = $d.width();\
   var center = (pagewidth / 2) - (thiswidth / 2);\
   var width = window.innerWidth || document.documentElement.clientWidth;\
   $d.css({\'left\': center, \'height\': \'100px\', \'margin\': \'0px\'}).appendTo(\'body\').slideDown("fast");\
}\
\
$(function() {\
   $(document).on("click","#saveform",function(a){\
         Popup("', T"Removing the ISP settings", '",a);\
         $("form#ISP").submit()\
   });\
   $(document).on("click","#saveformlogo",function(a){\
         Popup("', T"Removing the ISP Logo", '",a);\
         $("form#Logoform").submit()\
   });\
   $(document).on("click","#saveformcreate",function(a){\
         Popup("', T"Applying Config", '",a);\
         $("form#Permform").submit()\
   });\
   $(".control-label").css( {"width":"20%"} );\
});\
</script>\
<body>\
  <div class="feedback">\
  </div>\
    <div class="container">\
    <div class="row">\
      <div class="header span12">\
        <a href="', cui.nsplink, '" target="_blank"><img class="logo" src="', imgpath, 'logo.gif"></a>');
        local session = ngx.ctx.session
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
                    <ul class="dropdown-menu pull-right">
                      <li><a tabindex="-1" href="/password.lp" id="changepass">]]
            html[#html + 1] = T"Change my password"
            html[#html + 1] = [[ </a></li><li class="divider"></li><li><a tabindex="-1" href="/" id="usual"> ]]
            html[#html + 1] = T"User Interface"
            html[#html + 1] = [[ </a></li><li class="divider"></li><li><a tabindex="-2" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]
        end
        html[#html + 1] = [[</div>]]

        html[#html + 1] = [[<div class="pull-right">]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language())
        html[#html + 1] = [[</div>]]

        print(html,'\
      </div>\
    </div>\
    <div class="row">\
    <div class="offset3 span6">',
    ui_helper.createMessages(message_helper.popMessages()),'\
    </div>\
      <div class="offset3 span6">\
        <div class="smallcard httpi_card_large">',
          ui_helper.createCardHeader(format("%s",T"ISP File Control")),'\
          <div class="httpi_bg bg_large" data-bg-text="&#xf0c5;">\
            <div class="content httpi_content">\
               <form id="ISP" class="form-horizontal" method="post" action="/isp.lp">\
                               <input name="CSRFtoken" value="', ngx.ctx.session:getCSRFtoken(), '" type="hidden">\
                               <input name="action" value="SAVE" type="hidden">\
                               <input name="ispdelete" value="1" type="hidden">');
                local html = {}
                html[#html + 1] = ui_helper.createSimpleLight(light_map[ispvalue], state_map[ispvalue])
                if ispvalue == "Enabled" then
                html[#html + 1] = format("<div style=\"margin-top:10px;\"><div class='httpi_left'><strong>%s</strong></div>:  %s</div><br/>",T"Version", isp_content["isp_present"] )
                if isp_content["isp_present"] ~= "Created By GUI" then
                  html[#html + 1] = ui_helper.createAlertBlock(T"Deleting this is a final and cannot be undone", isp_warning)
                end
                html[#html+1] = format("<button type=\"submit\" id=\"saveform\" class=\"btn\">%s</button>",T"Delete")
                end
                ngx.print(html,'\
               </form>\
            </div>\
          </div>\
        </div>\
      </div>\
      <div class="offset3 span6">\
        <div class="smallcard httpi_card_large">',
          ui_helper.createCardHeader(format("%s",T"ISP Logo File")),'\
          <div class="httpi_bg bg_large" data-bg-text="&#xf0c5;">\
            <div class="content httpi_content">\
               <form id="Logoform" class="form-horizontal" method="post" action="/isp.lp">\
                               <input name="CSRFtoken" value="', ngx.ctx.session:getCSRFtoken(), '" type="hidden">\
                               <input name="action" value="SAVE" type="hidden">\
                               <input name="logodelete" value="1" type="hidden">');
                local html = {}
                html[#html + 1] = ui_helper.createSimpleLight(light_map[logovalue], state_map[logovalue])
                if logovalue == "Enabled" then
                html[#html + 1] = ui_helper.createAlertBlock(T"Deleting this is a final and cannot be undone", isp_warning)
                html[#html+1] = format("<button type=\"submit\" id=\"saveformlogo\" class=\"btn\">%s</button>",T"Delete")
                end
                ngx.print(html,'\
               </form>\
            </div>\
          </div>\
        </div>\
      </div>');
       if ispvalue ~= "Enabled" then
       ngx.print('\
      <div class="offset3 span6">\
        <div class="smallcard httpi_card_large">',      
          ui_helper.createCardHeader(format("%s",T"ISP Config Create")), '\
          <div class="httpi_bg bg_large" data-bg-text="&#xf0c5;">\
            <div class="content httpi_content">\
               <form id="Permform" class="form-horizontal" method="post" action="/isp.lp">\
                               <input name="CSRFtoken" value="', ngx.ctx.session:getCSRFtoken(), '" type="hidden">\
                               <input name="action" value="SAVE" type="hidden">\
                               <input name="ispcreate" value="1" type="hidden"> <!-- Avoid Chrome autofill -->');
                local html = {} 
                html[#html + 1] = ui_helper.createInputText(T"PPP Username","uci_wan_username", content["uci_wan_username"], class_username, helpmsg["uci_wan_username"])
                -- PPP password
                local class_password = class_username
                html[#html + 1] = ui_helper.createInputPassword(T"PPP Password", "uci_wan_password", content["uci_wan_password"], class_username, helpmsg["uci_wan_password"])
                html[#html + 1] = ui_helper.createInputText(T"ACS URL","uci_cwmp_url", content["uci_cwmp_url"],nil,helpmsg["uci_cwmp_url"])
                html[#html + 1] = format("<button type=\"submit\" id=\"saveformcreate\" class=\"btn\">%s</button>",T"Make Permanent")
                ngx.print(html, '\
               </form>\
            </div>\
          </div>\
        </div>\
      </div>');
      end
       --Content End
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
</html>');
