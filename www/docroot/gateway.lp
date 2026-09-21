<%
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
--Check for logo change
local lfs = require("lfs")
local imgpath = "/img/"
if lfs.attributes("/www/docroot/img/custom/logo.gif", "mode") == "file" then
  imgpath = "/img/custom/"
end

local session = ngx.ctx.session
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
}
content_helper.getExactContent(cui)

local version = ""
local tmpsplit = split(cui.version, "-")
if #tmpsplit > 1 then
   version = format("%s-%s",tmpsplit[1],tmpsplit[2])
end
         

if not session:isdefaultuser() then
  local proxy = require("datamodel")
  local first = format("%s",proxy.get("uci.env.var.first")[1].value)
  local username = session:getusername()
  if first then 
     if first == "1" and username == "admin" and laterpassword ~= "later" then
       ngx.redirect("/password.lp");
     end
  end
end

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
%>
<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
  <head>
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    <link rel="shortcut icon" href="/img/favicon.ico" type="image/vnd.microsoft.icon" />
    <meta name="Advanced" content="<%= cui.advanced %>">
    <link href="/css/gw.css" rel="stylesheet">
    <link href="/css/responsive.css" rel="stylesheet">
    <link href="/css/relf.css" rel="stylesheet">
    <link href="/css/color.css" rel="stylesheet">
    <link href="/css/loader.css" rel="stylesheet">   
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-min.js" ></script>
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->
    <title><%= T"Gateway" %></title>
  
  <script type='text/javascript'> 
    var refreshTimeOut = 35000;
    var refreshDelay = 2500;
    var down_check;
    var status_check;
    var L2_check;
    var L3_check;
    var WS_check; 
    
    function wait_for_webserver_down_gw() {
        var downcount = 0;
        var timecount = 0;
        $.ajax({ url: "/", timeout: refreshTimeOut })
        .done(function() {
          
        })   
        .fail(function() {
            down_check = window.setTimeout(function(){ 
              PopupRemove();
              Popup("<%= T"Timeout, attempting to reload" %>")
              window.location.href = "/"; 
            }, refreshDelay);
          });
    } 
    
    //Auth State and status check
    function connection_status_auth() {
        var iconOK  = "<i class=\"icon-link icon-small\"></i>"
        var iconNOK = "<i class=\"icon-unlink icon-small\"></i>"
        
        var check_timer = 10000;
        var check_timeout = 10000;
        var url = "/check_auth.lp";
        var isdefaultuser = "<%=session:isdefaultuser()%>";
        var redirecting = 0;
        $.ajax({ url: url, timeout: check_timeout })
        .done(function(x) {
              x = $.parseJSON(x);
              if (x.AUTH == "0" && isdefaultuser == "false"){
                PopupRemove();
                Popup("Login Expired. Reloading.");
                clearTimeout(status_check);
                window.setTimeout(function(){ 
                      window.location.href = "/"; 
                }, "3000");
                redirecting = 1; 
              }
              if ($("#bstatus").html() == iconNOK) {
                  if ($(".modal").length == 0)PopupRemove();
                  $("#bstatus").html(iconOK).css({"color":"#00FF00"}).tooltip();
              }
              
        })   
        .error(function() {
              if ($("#bstatus").html() == iconOK) {
                $("#bstatus").html(iconNOK).css({"color":"#FF0000"}).tooltip();
                
              }
          })
        .always(function() {
              if (redirecting == 0) status_check = window.setTimeout(function(){ connection_status_auth(); }, check_timer);         
        });
        
    }
    connection_status_auth();
    
    

    function Popup(x,check){
        var moveLeft = 10;
        var moveRight = -390;
        var moveDown = -50;
        var header = '<%= ui_helper.createCardHeader(T"Processing", "", "","")  %>';
       $("body").append('<div class=\"popUpBG\"></div>');
       $("body").append('<div id="popUp"  class="popUp smallcard span3">'+header+'<div id="Poptxt" class="content"></div>');
       
       
       x = x.concat('<br/><div id="spinner" class="spinner" align="center"><div class="spinner3"><div class="rect1"></div><div class="rect2"></div><div class="rect3"></div><div class="rect4"></div><div class="rect5"></div></div></div>');     
       $("#Poptxt").html(x);
       $d = $("#popUp");
       var pagewidth = $("body").width();
       var thiswidth = $d.width();
       var center = (pagewidth / 2) - ((thiswidth - 20) / 2);
       var width = window.innerWidth || document.documentElement.clientWidth;
       $d.css({'left': center,  'margin': '0px'}).appendTo('body');
       $('html, body').css({'overflow': 'hidden','height': '100%'}); 
       if (check == "1") {
          down_check = window.setTimeout(function(){ 
                wait_for_webserver_down_gw();
          }, refreshDelay * 2);
       }  
    } 
    function PopupRemove(){ 
      clearTimeout(down_check); 
      $('.popUpBG').remove();
      $('#popUp').remove();
      $('html, body').css({'overflow': 'auto','height': 'auto'});
    }
    
    
    $(function() {
          
          var pleasewait = "<%=T"Please wait..."%>";
          
          if(767<window.innerWidth){
            $('div .header-title[data-toggle="modal"]').parent().parent().click(function(){
                Popup(pleasewait,"1");
                
            });
          }
          
          
           
           $( document ).ajaxComplete(function( event, xhr, settings ) {
              var action = 0;
              var type = 0;
              if (settings.data){
                  if ((settings.data.indexOf("action=AJAX-GET") > -1)
                      ||(settings.data.indexOf("action=system") > -1)
                      ||(settings.data.indexOf("action=upgradefw") > -1)
                  )action = 1;
              } 
              if ((settings.url.indexOf("modal") > -1)
                &&(action == 0)
                &&(settings.url.indexOf("relf") == -1)
                &&(settings.url.indexOf("check=1") == -1)
                &&(settings.url.indexOf("upgrade") == -1)
                ){
                window.setTimeout(function(){
                  $("[data-dismiss='modal'], .modal-backdrop").click(function(){PopupRemove();Popup(pleasewait,"1");});
                  $(".btn.monitor-conn_mode, .modal-action.modal-action-refresh, #close-config.btn.btn-primary.btn-large, #save-config.btn.btn-primary.btn-large").click(function(){PopupRemove();Popup(pleasewait);});
                  $(".nav-tabs > li").not(".active").click(function(){PopupRemove();Popup(pleasewait);});
                  $(".nav-list li a").click(function(){PopupRemove();Popup(pleasewait);});
                  PopupRemove();
                  if (status_check){clearTimeout(status_check)};
                  if (L2_check){clearTimeout(L2_check)};
                  if (L3_check){clearTimeout(L3_check)};
                  if (WS_check){clearTimeout(WS_check)};
                 },500);
                
                
              }
              
           });
          <%
            if modal2load then
          %>
          var m = $("<div class='modal fade'></div>");
          m.appendTo("body");
          tch.loadModal("/modals/<%=modal2load%>", "", function() {
              m.modal();
          });
          <%
            end
          %> 
          PopupRemove();
    });

  </script>
  
</head> 
<body>
<div class="popUpBG"></div>
	<% if cui.versionmask:match("^%d%d%d9%d%d%d$") or cui.versionmask:match("^%d%d1%d%d%d%d$") then %>
    <%
	--[[<div style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px;">DEMO build, unofficial Technicolor SW, not suitable for deployment!</div>
	]]
	%>
	<% end %>
  <div class="feedback">

  </div>
    <div class="container">
    <div class="row">
      <div class="header span12">
        <a href="<%= cui.nsplink %>" target="_blank"><img class="logo" src="<%=imgpath%>logo.gif"></a>
        <%
        
        local html = {}

        html[#html + 1] = [[<div class="pull-right">]]
          
          html[#html + 1] = [[<div class="pull-left browserstatus" id="bstatus">]]
          html[#html + 1] = [[<i class="icon-link icon-small"></i>]]
          html[#html + 1] = [[</div>]]
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
    <div class="row"><div class="copyright span12">
      <p>&copy; Technicolor 2016</p>
       <p><%=format(T"Software Version: %s",version)%></p>
   </div></div>
    
  </div>
</body>
</html>
