<%
--NG-58110
-- Enable localization

gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local triesbeforemsg = 3
local content_helper = require("web.content_helper")

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "getcsrf" then
  ngx.print(ngx.ctx.session:getCSRFtoken())
  ngx.exit(ngx.HTTP_OK)
end

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
}
content_helper.getExactContent(cui)
local users = content_helper.getMatchedContent("uci.web.user.")
local userNames = ""
local legacySalts = ""

local httpi = proxy.get("rpc.network.interface.@wan.up")[1].value

for _, v in ipairs(users) do
  if v.legacy_salt ~= "" then
    userNames = userNames .. v.name ..","
    legacySalts = legacySalts .. v.legacy_salt .. ","
  end
end

local function reset_pass(path, value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" then
  local action = ngx.req.get_post_args().action
    if action == "res_pas" then
      return reset_pass("rpc.web.user.@usr_admin.reset", "1")
    end
end
%>
<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    <link href="/css/gw.css" rel="stylesheet">
    <link href="/css/responsive.css" rel="stylesheet">
	<link href="/css/TIM.css" rel="stylesheet">
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-min.js" ></script>
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->
    <script src="/js/srp-min.js" ></script>
    <title><%= T"Login" %></title>
</head>
<script type='text/javascript'> 
    function PopupWarning(x){
		
        var moveLeft = 10;
        var moveRight = -390;
        var moveDown = -50;
        var header = '<%= ui_helper.createCardHeader(T"Warning!", nil, nil, nil)  %>';
       $("body").append('<div class=\"popUpBG\"></div>')
       $("body").append('<div id="popUp"  class="popUp smallcard">'+header+'<div id="Poptxt" class="content"></div>')
	   $("#popUp").append('<div id="cstyle" style="margin-bottom:15px; "></div>')
	   $("#cstyle").append('<div class="btn btn-large" id="csoff">Cancel</div>')
       $("#cstyle").append('<div class="btn btn-primary btn-large" style="margin-left:3px;" id="confwarn">Confirm</div>')
	   
	   
       $("#Poptxt").html(x);
       $d = $("#popUp");
	   $c = $("#cstyle");
       var pagewidth = $("body").width();
       var thiswidth = $d.width();
       var center = (pagewidth / 2) - (thiswidth / 2);
       var width = window.innerWidth || document.documentElement.clientWidth;
       $d.css({'left': center,'background-color':'#82b9e6', 'margin': '0px'}).appendTo('body').slideDown("fast");
	   var pagewidth2 = $("#popUp").width();
       var thiswidth2 = $("#csoff").outerWidth() + $("#confwarn").outerWidth();
       var center2 = (pagewidth2 / 2) - (thiswidth2 / 2);
	   $c.css({'margin-left': center2}).appendTo('cstyle').slideDown("fast");
       $('html, body').css({'overflow': 'hidden','height': '100%'});
	   
	$("#confwarn").on("click", function(){
		PopupRemove();
		$("#erroruserpass").hide();
		$("#passwordmes").show();
		$("#passmes").show();
		$('#srp_password').val('');
		$(".control-group").removeClass("error");
		return reset_pass("res_pas");
	})
	
	$("#csoff").click(function(){
          var a=$(".modal form").attr("action");
		  PopupRemove();
		  tch.refreshModal(a);
		  });
    } 
    function PopupRemove(){  
      $('.popUpBG').remove();
      $('#popUp').remove();
      $('html, body').css({'overflow': 'auto','height': 'auto'});
    }   
	
  </script>
<body>
  <div class="container">
        <div class="logo-technicolor">
	<!--<a href="<%= cui.nsplink %>" target="_blank"><img src="/img/logo.png"></a>-->
	<img class="timlogo" src="/img/TIM.png">
	</div>
	<div class="row">
      <div class="offset4 span4">
        <div class="login">
        <form class="form-horizontal">
          <fieldset>
                <h2><%= T"Sign in" %></h2> 
                <% if httpi=='0' then  %>				
                <div id="httpi" class="alert alert-error ">
                    <strong><%= T"You don't have internet access at this time" %></strong>
                </div>
                <% end %>
            <div id="erroruserpass" class="alert alert-error hide">
               <strong><%= T"Invalid Username or Password" %></strong>
            </div>
			<div id="passwordmes" class="alert alert-success hide">
               <strong><%= T"Your Password has been reseted" %></strong>
            </div>
            <div class="control-group">
                <label for="srp_username"><div class="label-icon">
                    <i class="icon-user icon-large"></i>
                </div></label>
                <input class="span3" type="text" placeholder="<%= T"Your username" %>" id="srp_username" value="<%= cui.defaultuser %>" autofocus><br><br>
            </div>
			<div id="passmes" class="alert alert-success hide">
               <strong><%= T"Please fill in the password printed on the label." %></strong>
            </div>
            <div class="control-group">
                <label for="srp_password"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>
                <input class="span3" type="password" placeholder="<%= T"Your password" %>" id="srp_password"><br><br>
            </div>
            <!-- HIDE WARNING - NOT NOT USED IN DEFAULT CUSTO
            <div id="defaultpassword" class="alert alert-info hide">
                <%= T"If you haven't changed it, the default password can be found on the sticker under your gateway (it's called <strong>\"access code\"</strong>)" %>
            </div>
            -->
            <div class="pull-right">
				<div id="reset-pass" class="btn btn-primary btn-large"><%= T"Reset Password" %></div>
				&nbsp;
                <a href="/" class="btn btn-primary btn-large"><%= T"Cancel" %></a>
                &nbsp;
                <div id="sign-me-in" class="btn btn-primary btn-large"><%= T"Sign in" %></div>
            </div>
          </fieldset>
        </form>
      </div>
      </div>
    </div>
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor 2015</p></div></div>
  </div>
<script>
$(document).ready(
  function() {
    var triesbeforemsg = <%= triesbeforemsg %>;
    var tries = 0;
    var password = "";
    
    // Set the focus on the first input field
    $('form:first *:input[type!=hidden]:first').focus();
    // Handle press of enter. Could be handled by adding a hidden input submit but
    // this requires a lot of css tweaking to get it right since display:none does
    // not work on every browser. So go for the js way
    $('form input').keydown(function(e) {
        if(e.which == 13 || e.which == 10) {
            e.preventDefault();
            $("#sign-me-in").click();
        }
    });

    $("#sign-me-in").on("click", function () {
      $(this).text('<%= T"Verifying" %>');
      password = $("#srp_password")[0].value;

      //If the user has option legacy_salt, do migration
      var legacySalts = "<%= legacySalts %>";
      var userNames = "<%= userNames %>";
      var inputUsername = $("#srp_username")[0].value;
      var index = -1;
      var userNameArray = userNames.split(",")
      var legacySaltArray = legacySalts.split(",")

      for (var i = 0; i < userNameArray.length - 1; i ++)
      {
         if ( inputUsername == userNameArray[i] )
         {
           index = i;
         }
      }
      if (index >= 0)
      {
          //alert(legacySaltArray[index]);
          var hashObj = new jsSHA((legacySaltArray[index]+tch.stringToHex(password)), "HEX");
          password = hashObj.getHash("SHA-1", "HEX");
      }
      
      var srp = new SRP();
      srp.success = function() {
        // If we showed the login page using an internal redirect (detected
        // by checking if the URL ends with "/login.lp") then we simply
        // have to reload the page to get the actual page content now that
        // we're logged in.
        // Otherwise we explicitly go back to the main page.
        if (window.location.pathname.search(/\/login\.lp$/) == -1){
  		    var curl = window.location.href
          window.location.href = curl.substring(0,curl.indexOf("#"));
        }else
          window.location = "/";
      }
      srp.error_message = function(err) {
      if(err == 403){
        $.get("login.lp", {action:"getcsrf"}, function (data){
          $('meta[name=CSRFtoken]').attr('content', data);
          srp.identify("/authenticate", $("#srp_username")[0].value, password);
        });
      }else{
        $("#sign-me-in").text('<%= T"Sign in" %>');
        $("#erroruserpass").show();
        $(".control-group").addClass("error");
      }
        tries++;
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {
            $("#defaultpassword").show();
        }
      }
      srp.identify("/authenticate", $("#srp_username")[0].value, password);
    });
  })

  function reset_pass(action) {
    $.post(
      "login.lp",
      { action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },
      null,
      "json"
    );
    return false;
};
  $(document).ready(function() {
	$('#reset-pass').on("click", function(){
		PopupWarning("<%=T"Are you sure to reset your password?"%>");
	});
});
</script>
</body>
</html>
