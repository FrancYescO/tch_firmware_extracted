<%
--[[
V1.1 Added a flag check for the upgrade env variable to allow the page to redirect to a dedcated page for handling upgrades
      and the software version to the footer 
      and the script to allow popups 
      and the css for the popup

]]
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local format = string.format
local cui = {
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	versionmask = "uci.version.version.@version[0].mask",
   --Add line for checking for the upgrade flag
   upgrade = "uci.env.var.upgrade",
}
content_helper.getExactContent(cui)

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
--Additional check for upgrade flag
if cui.upgrade == "1" then
    proxy.set("uci.env.var.upgrade","0")
    proxy.apply()
    ngx.redirect("/upgrade.lp");
end



function split(x, sep)
        local sep, fields = sep or ":", {}
        local pattern = format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end


local sw = {
   version = "uci.version.version.@version[0].version",
}
content_helper.getExactContent(sw)


local version = ""
local tmpsplit = split(sw.version, "-")
if #tmpsplit > 1 then
   version = format("%s-%s",tmpsplit[1],tmpsplit[2])
end
%>
<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
  <head>
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    <meta name="Advanced" content="<%= cui.advanced %>">
    <link href="/css/gw.css" rel="stylesheet">
    <link href="/css/responsive.css" rel="stylesheet">
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-min.js" ></script>
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->
    <title><%= T"Gateway" %></title>
    <script type='text/javascript'> 
    function Popup(x){
        var moveLeft = 10;
        var moveRight = -390;
        var moveDown = -50;
        var header = '<%= ui_helper.createCardHeader(T"Processing", "", "","")  %>';
       $("body").append('<div class=\"popUpBG\"></div>')
       $("body").append('<div id="popUp"  class="smallcard span3">'+header+'<div id="Poptxt" class="content"></div>')
            
       $("#Poptxt").html(x);
       $d = $("#popUp");
       var pagewidth = $("body").width();
       var thiswidth = $d.width();
       var center = (pagewidth / 2) - (thiswidth / 2);
       var width = window.innerWidth || document.documentElement.clientWidth;
       $d.css({'left': center, 'height': '130px', 'margin': '0px'}).appendTo('body').slideDown("fast");
          
    } 
    function PopupRemove(){  
      $('.popUpBG').remove();
      $('#popUp').remove();
    }   
  </script>
  </head>

<body>
	<% if cui.versionmask:match("^%d%d%d9%d%d%d$") or cui.versionmask:match("^%d%d1%d%d%d%d$") then %>
	<% end %>
  <div class="feedback">

  </div>
    <div class="container">
    <div class="row">
      <div class="header span12">
        <a href="<%= cui.nsplink %>" target="_blank"><img src="/img/logo.gif"></a>
        <%
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
            html[#html + 1] = [[ </a></li><li class="divider"></li><li><a tabindex="-1" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]
        end
        html[#html + 1] = [[</div>]]

        html[#html + 1] = [[<div class="pull-right">]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language())
        html[#html + 1] = [[</div>]]

        ngx.print(html)
        %>
      </div>
    </div>
    <div class="row">
      <%
        local lp = require("web.lp")
        local cards = require("cards")
        for _,v in pairs(cards.cards()) do
          lp.include(v)
        end
      %>
    </div>
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor 2015</p><p><%=format(T"Software Version: %s",version)%></p></div></div>
  </div>
</body>
</html>
