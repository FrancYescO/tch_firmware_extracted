--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local triesbeforemsg = 3
local content_helper = require("web.content_helper")

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  nsplogo = "uci.web.uiconfig.@uidefault.nsplogo",
  timestamp = "uci.version.version.@version[0].timestamp",
}
content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year,1,4))

local logo_class = cui["nsplogo"]:match("logo%-(.+)%.") or ""
local stylesheet = cui["nsplogo"]:match("internode") and "/css/internode.css" or "/css/gw.css"
stylesheet = stylesheet .."?".. cui.timestamp

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

  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
<head>\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <link href="');  ngx.print( stylesheet ); ngx.print('" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css?');  ngx.print(cui.timestamp); ngx.print('"><![endif]-->\
    <script src="/js/main-min.js?');  ngx.print(cui.timestamp); ngx.print('" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js?');  ngx.print(cui.timestamp); ngx.print('"></script> <![endif]-->\
    <script src="/js/srp-min.js?');  ngx.print(cui.timestamp); ngx.print('" ></script>\
    <title>');  ngx.print( T"Change password" ); ngx.print('</title>\
</head>\
<body>\
  <div class="container">\
    <div class="logo-technicolor ');  ngx.print(logo_class); ngx.print('"><a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank"><img src="');  ngx.print('/img/' .. cui.nsplogo ); ngx.print('"></a></div>\
    <div class="row">\
      <div class="offset4 span4">\
        <div class="login">\
        <form class="form-horizontal">\
          <fieldset>\
                <h2>');  ngx.print( T"Change password" ); ngx.print('</h2>\
            <div id="erroruserpass" class="alert alert-error hide">\
               <strong>');  ngx.print( T"Invalid Password" ); ngx.print('</strong>\
            </div>\
\
            ');  ngx.print( createPwdLabel(T"Your old password") ); ngx.print('\
            <div class="control-group">\
                <label for="srp_password"><div class="label-icon">\
                    <i class="icon-lock icon-large"></i>\
                </div></label>\
                <input class="span3" type="password" id="srp_password" autofocus><br><br>\
            </div>\
            <!-- HIDE WARNING - NOT USED IN DEFAULT CUSTO\
            <div id="defaultpassword" class="alert alert-info hide">\
                ');  ngx.print( T"If you haven't changed it, the default password can be found on the sticker under your gateway (it's called <strong>\"access code\"</strong>)" ); ngx.print('\
            </div>\
            -->\
            ');  ngx.print( createPwdLabel(T"Your new password") ); ngx.print('\
            <div class="control-group">\
                <label for="srp_password_new_1"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                <input class="span3" type="password" id="srp_password_new_1"><br><br>\
            </div>\
            ');  ngx.print( createPwdLabel(T"Repeat new password") ); ngx.print('\
            <div class="control-group">\
                <label for="srp_password_new_2"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                <input class="span3" type="password" id="srp_password_new_2"><br><br>\
            </div>\
            <div class="pull-right">\
                <a href="/" class="btn btn-primary btn-large">');  ngx.print( T"Cancel" ); ngx.print('</a>\
                &nbsp;\
                <div id="change-my-pass" class="btn btn-primary btn-large">');  ngx.print( T"Change password" ); ngx.print('</div>\
            </div>\
          </fieldset>\
        </form>\
      </div>\
      </div>\
    </div>\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print(' </p></div></div>\
  </div>\
<script>\
$(document).ready(\
  function() {\
    var triesbeforemsg = ');  ngx.print( triesbeforemsg ); ngx.print(';\
    var tries = 0;\
\
    function display_error()\
    {\
        $("#change-my-pass").text(\'');  ngx.print( T"Change password" ); ngx.print('\');\
        $("#erroruserpass").show();\
        $(".control-group").addClass("error");\
        tries++;\
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {\
            $("#defaultpassword").show();\
        }\
    }\
\
    // Set the focus on the first input field\
    $(\'form:first *:input[type!=hidden]:first\').focus();\
    // Handle press of enter. Could be handled by adding a hidden input submit but\
    // this requires a lot of css tweaking to get it right since display:none does\
    // not work on every browser. So go for the js way\
    $(\'form input\').keydown(function(e) {\
        if(e.which == 13 || e.which == 10) {\
            e.preventDefault();\
            $("#change-my-pass").click();\
        }\
    });\
\
    $("#change-my-pass").on("click", function () {\
      if ($("#srp_password_new_1")[0].value != $("#srp_password_new_2")[0].value) {\
        display_error();\
        return false;\
      }\
      $(this).text(\'');  ngx.print( T"Updating" ); ngx.print('\');\
      var srp = new SRP();\
      srp.success = function() {\
        srp.generateSaltAndVerifier("/password", \'');  ngx.print( ngx.ctx.session:getusername() ); ngx.print('\', $("#srp_password_new_1")[0].value)\
      }\
      srp.passwordchanged = function() {\
        window.location = "/";\
      }\
      srp.error_message = function() {\
        display_error();\
      }\
      srp.identify("/password", \'');  ngx.print( ngx.ctx.session:getusername() ); ngx.print('\', $("#srp_password")[0].value);\
    });\
  })\
</script>\
</body>\
</html>\
'); 