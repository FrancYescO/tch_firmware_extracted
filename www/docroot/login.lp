--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local format = string.format
local triesbeforemsg = 1
local toomanysecs = 5
local content_helper = require("web.content_helper")

function split(x, sep)
        local sep, fields = sep or ":", {}
        local pattern = format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

--Check for logo change
local lfs = require("lfs")
local imgpath = "/img/"
if lfs.attributes("/www/docroot/img/custom/logo.gif", "mode") == "file" then
  imgpath = "/img/custom/"
end

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "getcsrf" then
  ngx.print(ngx.ctx.session:getCSRFtoken())
  ngx.exit(ngx.HTTP_OK)
end

local check = {
            isp = "sys.ispconfig.Present",
            upgraded = "uci.env.custovar.upgraded",
      }      
content_helper.getExactContent(check)


local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
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

local users = content_helper.getMatchedContent("uci.web.user.")
local userNames = ""
local legacySalts = ""

for _, v in ipairs(users) do
  if v.legacy_salt ~= "" then
    userNames = userNames .. v.name ..","
    legacySalts = legacySalts .. v.legacy_salt .. ","
  end
end

ngx.print('\
<!DOCTYPE HTML>\
', string.format('<html lang="%s">', gettext.language()), '\
<head>\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="', ngx.ctx.session:getCSRFtoken(), '">\
    <link href="/css/gw.css" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
    <link href="/css/color.css" rel="stylesheet">\
    <link href="/css/relf.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <script src="/js/srp-min.js" ></script>\
    <title>', T"Login", '</title>\
</head>\
<body>\
  <div class="container">\
    <div class="logo-technicolor"><a href="', cui.nsplink, '" target="_blank"><img class="logo" src="', imgpath, 'logo.gif"></a></div>\
    <div class="row">\
      <div class="offset4 span4">\
        <div class="login" id = "login">\
        <form class="form-horizontal">\
          <fieldset>\
                <h2>', T"Sign in", '</h2>\
            <div id="erroruserpass" class="alert alert-error hide">\
               <strong>',  T"Invalid Username or Password", '</strong>\
            </div>\
            <div class="control-group">\
                <label for="srp_username"><div class="label-icon">\
                    <i class="icon-user icon-large"></i>\
                </div></label>\
                <input class="span3" type="text" placeholder="', T"Your username", '" id="srp_username" value="', cui.defaultuser, '" autofocus><br><br>\
            </div>\
            <div class="control-group">\
                <label for="srp_password"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                <input class="span3" type="password" placeholder="', T"Your password", '" id="srp_password"><br><br>\
            </div>\
            <div id="defaultpassword" class="alert alert-info hide">', 
	    	T"If you haven't changed your password, the default is the <strong>\"ACCESS KEY\"</strong> and can be found on the label of your gateway.",
                '<img class="label" rel="tooltip" data-placement="top" data-original-title="', T"Example label", '" src="/img/label.png" alt="label">\
            </div>\
            <div id="toomany" class="alert alert-info hide">',
                T"Too many password attempts</br>",
                '<p id="toomanttime">', T"<strong>Please wait...</strong>", '</p>\
            </div>\
            <div class="pull-right">\
                <div id="cancel" class="btn btn-primary btn-large">', T"Cancel", '</div>\
                &nbsp;\
                <div id="sign-me-in" class="btn btn-primary btn-large">', T"Sign in", '</div>\
            </div>\
          </fieldset>\
        </form>\
      </div>\
      <div class="login hide" id ="forgot-login">\
        <form class="form-horizontal">\
          <fieldset>\
            <h2>', T"Reset Password", '</h2>\
            <div id="erroruserpass1" class="alert alert-error hide">\
              <strong>', T"Invalid Password", '</strong>\
            </div>\
            <div class="control-group">\
              <label for="srp_password1" class="alert-info">', T'Enter the default <strong>"access code"</strong>. This code is located on the label underneath your gateway.</label>\
              <label for="srp_password1"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
              <input class="span3" type="password" placeholder="', T"Your password",'" id="srp_password1"><br><br>\
            </div>\
            <div class="pull-right">\
              <a href="/" class="btn btn-primary btn-large">', T"Cancel", '</a>&nbsp;\
              <div id="verify-password" class="btn btn-primary btn-large">', T"Verify", '</div>\
            </div>\
          </fieldset>\
        </form>\
      </div>\
      </div>\
    </div>\
    <div class="row">\
      <div class="copyright span12">\
        <p>&copy; Technicolor ',current_year, '</p>\
        <p>', format(T"Software Version: %s",version), '</p>\
      </div>\
    </div>\
  </div>\
<script>\
\
function PopupBGRemove(){\
  $(\'.popUpBG\').remove();\
  $(\'html, body\').css({\'overflow\': \'auto\',\'height\': \'auto\'});\
}\
function PopupBG(){\
   $("body").append(\'<div class=\"popUpBG\"></div>\');\
   $(\'html, body\').css({\'overflow\': \'hidden\',\'height\': \'1000%\'});\
}\
$(document).ready(\
  function() {\
    var triesbeforemsg = ', triesbeforemsg, ';\
    var toomanysecs = ', toomanysecs, ';\
    var tries = 0;\
    var isp = "', check.isp, '";\
    var upgraded = "', check.upgraded, '"\
    var password = "";\
\
    // Set the focus on the first input field\
    $(\'form:first *:input[type!=hidden]:first\').focus();\
    // Handle press of enter. Could be handled by adding a hidden input submit but\
    // this requires a lot of css tweaking to get it right since display:none does\
    // not work on every browser. So go for the js way\
    $(\'form input\').keydown(function(e) {\
        if(e.which == 13 || e.which == 10) {\
            e.preventDefault();\
            $("#sign-me-in").click();\
        }\
    });\
   $("#cancel").on("click", function () {\
      window.location.href="/";\
   });\
    $("#sign-me-in").on("click", function () {\
      $(this).text(\'', T"Verifying", '\');\
      password = $("#srp_password")[0].value;\
\
      //If the user has option legacy_salt, do migration\
      var legacySalts = "', legacySalts, '";\
      var userNames = "', userNames, '";\
      var inputUsername = $("#srp_username")[0].value;\
      var index = -1;\
      var userNameArray = userNames.split(",")\
      var legacySaltArray = legacySalts.split(",")\
\
      for (var i = 0; i < userNameArray.length - 1; i ++)\
      {\
         if ( inputUsername == userNameArray[i] )\
         {\
           index = i;\
         }\
      }\
      if (index >= 0)\
      {\
          var hashObj = new jsSHA((legacySaltArray[index]+tch.stringToHex(password)), "HEX");\
          password = hashObj.getHash("SHA-1", "HEX");\
      }\
\
      var srp = new SRP();\
      srp.success = function() {\
        // If we showed the login page using an internal redirect (detected\
        // by checking if the URL ends with "/login.lp") then we simply\
        // have to reload the page to get the actual page content now that\
        // we\'re logged in.\
        // Otherwise we explicitly go back to the main page.\
        if (window.location.pathname.search(/\\/login\\.lp$/) == -1){\
  		    var curl = window.location.href\
          window.location.href = curl.substring(0,curl.indexOf("#"));\
        }else\
          window.location = "/";\
      }\
      srp.error_message = function(err) {\
      if(err == 403){\
        $.get("login.lp", {action:"getcsrf"}, function (data){\
          $(\'meta[name=CSRFtoken]\').attr(\'content\', data);\
          srp.identify("/authenticate", $("#srp_username")[0].value, password);\
        });\
      }else{\
        $("#sign-me-in").text(\'', T"Sign in", '\');\
        $("#erroruserpass").show();\
        $(".control-group").addClass("error");\
      }\
        tries++;\
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {\
          if (isp != "0" || upgraded != "0") {\
            $("#defaultpassword").html("', T"If you haven't changed your password, please refer to your installation guide.", '")\
          }\
          $("#defaultpassword").show();\
        }\
        if (tries % 3 == 0){\
            var multiplier = (tries / 3) * (tries / 3);\
            PopupBG();\
            $("#toomanttime").html(\'', T"<strong>Please wait...</strong>", '\' + toomanysecs * multiplier + \' ', T"seconds", '\');\
            $("#toomany").show();\
            window.setTimeout(function(){\
                PopupBGRemove();\
                $("#toomany").hide();\
            },toomanysecs * 1000 * multiplier);\
          }\
      }\
      srp.identify("/authenticate", $("#srp_username")[0].value, password);\
    });\
    $("#forgot-login-password").on("click", "a", function(){\
      $("#login").hide();\
      $("#forgot-login").show();\
    });\
    $("#verify-password").click(function(){\
      var srp = new SRP();\
      srp.success = function() {\
        window.location = "/password-reset.lp";\
        $("#login").hide();\
        $("#forgot-login").hide();\
      }\
      srp.error_message = function(err) {\
        $("#verify-password").text(\'', T"Verify", '\');\
        $("#erroruserpass1").show();\
        $(".control-group").addClass("error");\
      }\
      if (this.id == "verify-password")\
     {\
       password = $("#srp_password1").val();\
     }\
     srp.identify("/authenticate", "forgotpassword", password);\
    });\
  })\
</script>\
</body>\
</html>');
