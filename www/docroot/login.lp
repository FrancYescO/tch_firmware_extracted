--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local triesbeforemsg = 3
local content_helper = require("web.content_helper")
local format,find,sub,untaint = string.format, string.find, string.sub, string.untaint

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "getcsrf" then
  ngx.print(ngx.ctx.session:getCSRFtoken())
  ngx.exit(ngx.HTTP_OK)
end

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  nsplogo = "uci.web.uiconfig.@uidefault.nsplogo",
  timestamp = "uci.version.version.@version[0].timestamp",
  firmware_version = "uci.version.version.@version[0].version",
  fwversion_prefix = "uci.versioncusto.override.fwversion_prefix",
  fwversion_suffix = "uci.versioncusto.override.fwversion_suffix",
  fwversion_override = "uci.versioncusto.override.fwversion_override",
}
content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year,1,4))
if cui["firmware_version"] then
  local version = cui["firmware_version"]
  cui["firmware_version"] = cui.fwversion_prefix .. sub(version, 1, find(version, "%-[^%-]*$") - 1) .. cui.fwversion_suffix
  if cui.fwversion_override then
    if cui.fwversion_override == "override1" then
      cui["firmware_version"] = cui.fwversion_prefix .. sub(version, 1, find(version, "%-") -1) .. cui.fwversion_suffix
    end
  end
end

local logo_class = cui["nsplogo"]:match("logo%-(.+)%.") or ""
local stylesheet = cui["nsplogo"]:match("internode") and "/css/internode.css" or "/css/gw.css"
stylesheet = stylesheet .."?".. cui.timestamp
  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
<head>\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <link href="');  ngx.print( stylesheet ); ngx.print('" rel="stylesheet">\
    <link href="/css/responsive.css?');  ngx.print(cui.timestamp); ngx.print('" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css?');  ngx.print(cui.timestamp); ngx.print('"><![endif]-->\
    <script src="/js/main-min.js?');  ngx.print(cui.timestamp); ngx.print('" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js?');  ngx.print(cui.timestamp); ngx.print('"></script> <![endif]-->\
    <script src="/js/srp-min.js?');  ngx.print(cui.timestamp); ngx.print('" ></script>\
    <title>');  ngx.print( T"Login" ); ngx.print('</title>\
</head>\
<body>\
  <div class="container">\
    <div class="logo-technicolor ');  ngx.print(logo_class); ngx.print('"><a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank"><img src="');  ngx.print('/img/' .. cui.nsplogo ); ngx.print('"></a></div>\
    <div class="row">\
      <div class="offset4 span4">\
        <div class="login">\
        <form class="form-horizontal">\
          <fieldset>\
                <h2>');  ngx.print( T"Sign in" ); ngx.print('</h2>\
            <div id="erroruserpass" class="alert alert-error hide">\
               <strong>');  ngx.print( T"Invalid Username or Password" ); ngx.print('</strong>\
            </div>\
            <div class="control-group">\
                <label for="srp_username"><div class="label-icon">\
                    <i class="icon-user icon-large"></i>\
                </div></label>\
                <input class="span3" type="text" placeholder="');  ngx.print( T"Your username" ); ngx.print('" id="srp_username" value="');  ngx.print( cui.defaultuser ); ngx.print('" autofocus><br><br>\
            </div>\
            <div class="control-group">\
                <label for="srp_password"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                <input class="span3" type="password" placeholder="');  ngx.print( T"Your password" ); ngx.print('" id="srp_password"><br><br>\
            </div>\
            <!-- HIDE WARNING - NOT NOT USED IN DEFAULT CUSTO\
            <div id="defaultpassword" class="alert alert-info hide">\
                ');  ngx.print( T"If you haven't changed it, the default password can be found on the sticker under your gateway (it's called <strong>\"access code\"</strong>)" ); ngx.print('\
            </div>\
            -->\
            <div class="pull-right">\
                <a href="/" class="btn btn-primary btn-large">');  ngx.print( T"Cancel" ); ngx.print('</a>\
                &nbsp;\
                <div id="sign-me-in" class="btn btn-primary btn-large">');  ngx.print( T"Sign in" ); ngx.print('</div>\
            </div>\
          </fieldset>\
        </form>\
      </div>\
      </div>\
    </div>\
    <div class="row"><div class="copyright span12"><p>');  ngx.print( cui.firmware_version ); ngx.print('</p><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
  </div>\
<script>\
$(document).ready(\
  function() {\
    var triesbeforemsg = ');  ngx.print( triesbeforemsg ); ngx.print(';\
    var tries = 0;\
    window.sessionStorage.removeItem("current_role");\
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
\
    $("#sign-me-in").on("click", function () {\
      $(this).text(\'');  ngx.print( T"Verifying" ); ngx.print('\');\
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
          srp.identify("/authenticate", $("#srp_username")[0].value, $("#srp_password")[0].value);\
        });\
      }else{\
        $("#sign-me-in").text(\'');  ngx.print( T"Sign in" ); ngx.print('\');\
        $("#erroruserpass").show();\
        $(".control-group").addClass("error");\
      }\
        tries++;\
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {\
            $("#defaultpassword").show();\
        }\
      }\
      srp.identify("/authenticate", $("#srp_username")[0].value, $("#srp_password")[0].value);\
    });\
  })\
</script>\
</body>\
</html>\
'); 