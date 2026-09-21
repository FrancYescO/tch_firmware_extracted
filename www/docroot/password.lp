<%
-- Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local triesbeforemsg = 3
local content_helper = require("web.content_helper")
local format = string.format
local session = ngx.ctx.session

--Check for logo change
local lfs = require("lfs")
local imgpath = "/img/"
if lfs.attributes("/www/docroot/img/custom/logo.gif", "mode") == "file" then
  imgpath = "/img/custom/"
end

if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_post_args().action
  -- now process non-file POSTs
  if action == "later" then
    proxy.set("uci.env.custovar.first","1")
    proxy.apply()
    session:store("first","later")
    ngx.redirect("/") 
  end 
end




local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
}
content_helper.getExactContent(cui)

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




--Added for the first time login prompt - start

local first = format("%s",proxy.get("uci.env.custovar.first")[1].value)
local cancel = T"Skip"
if not first then 
   first = "0"
   proxy.add("uci.env.custovar.first")
end

local hide = "" 
if first ~= "1" then 
      hide = "hide"
      cancel = T"Cancel" 
end
proxy.set("uci.env.custovar.first","0")
proxy.apply()

--Added for the first time login prompt - end
%>
<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
<head>
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    <link rel="shortcut icon" href="/img/favicon.ico" type="image/vnd.microsoft.icon" />
    <link href="/css/gw.css" rel="stylesheet">
    <link href="/css/responsive.css" rel="stylesheet">
    <link href="/css/color.css" rel="stylesheet">
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-min.js" ></script>
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->
    <script src="/js/srp-min.js" ></script>
    <title><%= T"Change password" %></title>
    
<style>  
#Strength{height:5px;display:block;float:left;margin-left:40px;}
.strength0{width:10px;background:#ff0000;}
.strength1{width:55px;background:#ff0000;}
.strength2{width:100px;background:#FF9900;}
.strength3{width:140px;background:#FFFF00;}
.strength4{width:185px;background:#33CC33;}
.strength5{width:215px;background:#00FF00;}
</style>
</head>
<body>
  <div class="container">
    <div class="logo-technicolor"><a href="<%= cui.nsplink %>" target="_blank"><img class="logo" src="<%=imgpath%>logo.gif"></a></div>
    <div class="row">
      <div class="offset4 span4">
        <div class="login">
        <form class="form-horizontal">
          <fieldset>
                <h2><%= T"Change password" %></h2>
                
                <p class="<%= hide %>">
                <strong><%= T"First Time Login : " %></strong><%= T"It is recommened you set a unique password that is easy for you to remember."%>
                </P>
            <div id="erroruserpass" class="alert alert-error hide">
               <strong><%= T"Invalid Password" %></strong>
            </div>

            <%= createPwdLabel(T"Your old password") %>
            <div class="control-group">
                <label for="srp_password"><div class="label-icon">
                    <i class="icon-lock icon-large"></i>
                </div></label>
                <input class="span3" type="password" id="srp_password" autofocus><br><br>
            </div>
            <!-- HIDE WARNING - NOT USED IN DEFAULT CUSTO
            <div id="defaultpassword" class="alert alert-info hide">
                <%= T"If you haven't changed it, the default password can be found on the sticker under your gateway (it's called <strong>\"access code\"</strong>)" %>
            </div>
            -->
            <%= createPwdLabel(T"Your new password") %>
            <div class="control-group">
                <label for="srp_password_new_1"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>
                <input class="span3" type="password" id="srp_password_new_1" onkeyup="passwordCheck(this.value)"><br>
                <label for="Strength"></label>
                <div id="Strength" class="span3 strength0"></div><br>
            </div>
            <div id="erroruserpass2" class="alert alert-error hide">
               <strong><%= T"Passwords do not match" %></strong>
            </div>
            <%= createPwdLabel(T"Repeat new password") %>
            <div class="control-group">
                <label for="srp_password_new_2"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>
                <input class="span3" type="password" id="srp_password_new_2"><br><br>
            </div>
            <div class="pull-right">
              
                <div id="ask-me-again" class="btn btn-primary btn-large <%=hide%>"><%= T"Later" %></div>
                &nbsp;
                <a href="/" class="btn btn-primary btn-large"><%= cancel %></a>
                &nbsp;
                <div id="change-my-pass" class="btn btn-primary btn-large"><%= T"Change password" %></div>
            </div>
          </fieldset>
        </form>
      </div>
      </div>
    </div>
    
    <div class="row">
      <div class="copyright span12">
         <p>&copy; Technicolor 2016</p>
      </div>
    </div>
  </div>
<script>
function passwordCheck(password)
{

	var level = 0;

	//if password bigger than 6 give 1 point
	if (password.length >= 6) level++;

	//if password has both lower and uppercase characters give 1 point	
	if ( ( password.match(/[a-z]/) ) && ( password.match(/[A-Z]/) ) ) level++;

	//if password has at least one number give 1 point
	if (password.match(/\d+/)) level++;

	//if password has at least one special caracther give 1 point
	if ( password.match(/.[!,@,#,$,%,^,&,*,?,_,~,-,(,)]/) )	level++;

	//if password bigger than 8 give another 1 point
	if (password.length >= 8) level++;

	 
	 $('#Strength').removeClass().addClass("strength" + level).addClass("span3");
}

$(document).ready(
  function() {
    var triesbeforemsg = <%= triesbeforemsg %>;
    var tries = 0;

    function display_error(x)
    {
        $("#change-my-pass").text('<%= T"Change password" %>');
        $("#erroruserpass").show();
        $(".control-group").addClass("error");
        tries++;
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {
            $("#defaultpassword").show();
        }
    }

    // Set the focus on the first input field
    $('form:first *:input[type!=hidden]:first').focus();
    // Handle press of enter. Could be handled by adding a hidden input submit but
    // this requires a lot of css tweaking to get it right since display:none does
    // not work on every browser. So go for the js way
    $('form input').keydown(function(e) {
        if(e.which == 13 || e.which == 10) {
            e.preventDefault();
            $("#change-my-pass").click();
        }
    });

    $("#change-my-pass").on("click", function () {
      if ($("#srp_password_new_1")[0].value != $("#srp_password_new_2")[0].value) {
        //display_error();
        $("#erroruserpass2").show();
        return false;
      }else{
        $("#erroruserpass2").hide();
      }
      $(this).text('<%= T"Updating" %>');
      var srp = new SRP();
      srp.success = function() {
        srp.generateSaltAndVerifier("/password", '<%= ngx.ctx.session:getusername() %>', $("#srp_password_new_1")[0].value)
      }
      srp.passwordchanged = function() {
        window.location = "/";
      }
      srp.error_message = function() {
        display_error();
      }
      srp.identify("/password", '<%= ngx.ctx.session:getusername() %>', $("#srp_password")[0].value);
    });
    
      

      $("#ask-me-again").on("click",function(a){
         a.preventDefault();
         a=$("\x3cform\x3e",{action:"/password.lp",method:"post"})
         .append($("\x3cinput\x3e",{name:"action",value:"later",type:"hidden"}))
         .append($("\x3cinput\x3e",{name:"URL",value:"<%=redirected_URL%>",type:"hidden"}))
         .append($("\x3cinput\x3e",{name:"CSRFtoken",value:$("meta[name\x3dCSRFtoken]").attr("content"),type:"hidden"}));
         $("body").append(a);
         //Popup("<%=T"Please wait..."%>",a);
         a.submit();
        });  
  })
</script>
</body>
</html>
