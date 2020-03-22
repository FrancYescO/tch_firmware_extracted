--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local triesbeforemsg = 3
local content_helper = require("web.content_helper")
local untaint = string.untaint
local proxy = require("datamodel")

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "PasswordChanged" then
   local result = content_helper.getMatchedContent("uci.web.user.", {name = ngx.ctx.session:getusername()})
    if result and #result > 0 then
      if proxy.set(result[1].path .. "password_reminder", "0") then
        proxy.apply()
      end
    end
    ngx.exit(ngx.HTTP_OK)
end

local ui_helper = require("web.ui_helper")
local table, ipairs, istainted, format = table, ipairs, string.istainted, string.format
local login_side = nil
local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  timestamp = "uci.version.version.@version[0].timestamp",
}
if ngx.var.server_port ~= nil then
  local server_port = format("%s", ngx.var.server_port)
  if server_port == "443" then
 login_side = "wan"
  end
end

content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year,1,4))

if ngx.req.get_method() == "POST" then
  local user_list = "uci.web.sessionmgr.@default.users."
  if login_side == "wan" then
      user_list = "uci.web.sessionmgr.@wandefault.users."
  end
  local user_tab_list = proxy.get(user_list)
  local post_args = ngx.req.get_post_args()
  local user_name_list ={}
  local ret = ngx.ctx.session:changePassword(post_args.salt, post_args.verifier)
  local current_usr_name = ngx.ctx.session:getusername()
  if ret and post_args.reminder then
     for _,v in pairs(user_tab_list) do
        local path_usr = "uci.web.user.@"..v.value..".name"
	local user_name = proxy.get(path_usr)
	if user_name and user_name[1].value == current_usr_name then
	   local val = string.format("%s", v.value)
	   local path_reminder = "uci.web.user.@" .. val .. ".password_reminder"
	   local succ = proxy.set(path_reminder, post_args.reminder)
	   if succ then
	      proxy.apply()
	   end
	   break
	end
     end
  end
end

--Start for legacy migration: GUI username/password [NG-48489]
local users = content_helper.getMatchedContent("uci.web.user.")
local userNames = ""
local legacySalts = ""

for _, v in ipairs(users) do
  if v.legacy_salt ~= "" then
    userNames = userNames .. v.name ..","
    legacySalts = legacySalts .. v.legacy_salt .. ","
  end
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().resetLegacySalt then
  --As the legacy user password has changed, to remove the legacy label,i.e., option legacy_salt.
  local user = content_helper.getMatchedContent("uci.web.user.", {name = ngx.ctx.session:getusername()})
  if user and #user > 0 then
    user = user[1]
    proxy.set(user.path .. "legacy_salt", "")
    proxy.apply()
  end
end
--End for legacy migration: GUI username/password [NG-48489]

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
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <link href="/css/gw.css" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <script src="/js/srp-min.js" ></script>\
    <title>');  ngx.print( T"Change password" ); ngx.print('</title>\
\
</head>\
<body>\
  <div class="container">\
    <div class="logo-technicolor"><a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank"><img src="/img/logo.gif"></a></div>\
    <div class="row">\
      <div class="offset4 span4">\
        <div class="login">\
        <form class="form-horizontal">\
          <fieldset>\
                <h2>');  ngx.print( T"Change password" ); ngx.print('</h2>\
            <div id="erroruserpass" class="alert alert-error hide">\
                <strong>');  ngx.print( T"Passwords do not match" ); ngx.print('</strong>\
            </div>\
\
            <div id="erroruserpass_2" class="alert alert-error hide">\
               <strong>');  ngx.print( T"Password must contain at least 10 alphanumeric characters including both upper and lower case letters, at least one number and at least one special character" ); ngx.print('</strong>\
            </div>\
\
            <div id="erroruserpass_3" class="alert alert-error hide">\
               <strong>');  ngx.print( T"Provide a password to prevent unauthorized access to the gateway"); ngx.print('</strong>\
            </div>\
\
            <div id="erroruserpass_4" class="alert alert-error hide">\
               <strong>');  ngx.print( T"Old password is incorrect"); ngx.print('</strong>\
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
                ');  ngx.print( T"If you haven't changed it, the default password can be found on the sticker under your gateway (it's called <strong>\"wireless key\"</strong>)" ); ngx.print('\
            </div>\
            -->\
            ');  ngx.print( createPwdLabel(T"Your new password") ); ngx.print('\
            <div class="control-group">\
                <label for="srp_password_new_1"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                <input class="span3" type="password" id="srp_password_new_1" onkeyup="passwordCheck(this.value)"><br>\
                <label for="Strength"></label>\
                <div id="Password_Strength" class="span3"></div><br>\
            </div>\
            ');  ngx.print( createPwdLabel(T"Repeat new password") ); ngx.print('\
            <div class="control-group">\
                <label for="srp_password_new_2"><div class="label-icon"><i class="icon-lock icon-large"></i></div></label>\
                <input class="span3" type="password" id="srp_password_new_2"><br><br>\
            </div>\
            ');  ngx.print( createPwdLabel(T"Password reminder","") ); ngx.print('\
            <div class="control-group">\
                <label for="reminder"><div class="label-icon"><i class="icon-info icon-large"></i></div></label>\
                <input class="span3" type="text" id="reminder">\
                <br><br>\
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
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
  </div>\
<script>\
function passwordCheck(password)\
{\
\
	var level = 0;\
\
	//if password bigger than 6 give 1 point\
	if (password.length >= 6) level++;\
\
	//if password has both lower and uppercase characters give 1 point\
	if ( ( password.match(/[a-z]/) ) && ( password.match(/[A-Z]/) ) ) level++;\
\
	//if password has at least one number give 1 point\
	if (password.match(/\\d+/)) level++;\
\
	//if password has at least one special caracther give 1 point\
	if ( password.match(/.[!,@,#,$,%,^,&,*,?,_,~,-,(,)]/) )	level++;\
\
	//if password bigger than 8 give another 1 point\
	if (password.length >= 8) level++;\
\
	 $(\'#Password_Strength\').removeClass().addClass("pstrength" + level).addClass("span3");\
         return level;\
}\
\
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
    $(".alert").hide();\
      if ($("#srp_password_new_1")[0].value != $("#srp_password_new_2")[0].value) {\
        display_error();\
        return false;\
      }\
\
      var password1 = $("#srp_password_new_1")[0].value;\
      var password2 = $("#srp_password_new_2")[0].value;\
      if(password1.length < 10 || passwordCheck(password1) < 5)\
         {\
            if(password1.length == 0)\
            {\
              $("#erroruserpass_3").show();\
              $(".control-group").addClass("error");\
              return false;\
            }\
            $("#erroruserpass_2").show();\
            $(".control-group").addClass("error");\
            return false;\
         }\
      $(this).text(\'');  ngx.print( T"Updating" ); ngx.print('\');\
      var username = \'');  ngx.print( ngx.ctx.session:getusername() ); ngx.print('\';\
      var password = $("#srp_password")[0].value;\
      //Start for legacy migration: GUI username/password [NG-48489]\
      /*\
      If the user has option legacy_salt, means it is migrated from the legacy build.\
      Then user the sha1 hash of the password to authenticate.\
      */\
      var legacySalts = "');  ngx.print( legacySalts ); ngx.print('";\
      var userNames = "');  ngx.print( userNames ); ngx.print('";\
      var index = -1;\
      var userNameArray = userNames.split(",")\
      var legacySaltArray = legacySalts.split(",")\
\
      for (var i = 0; i < userNameArray.length - 1; i ++)\
      {\
         if ( username == userNameArray[i] )\
         {\
           index = i;\
         }\
      }\
      if (index >= 0)\
      {\
         var hashObj = new jsSHA((legacySaltArray[index]+tch.stringToHex(password)), "HEX");\
         password = hashObj.getHash("SHA-1", "HEX");\
      }\
      //End for legacy migration: GUI username/password [NG-48489]\
      var srp = new SRP();\
      srp.success = function() {\
          srp.generateSaltAndVerifierTheCallback(\'');  ngx.print( ngx.ctx.session:getusername() ); ngx.print('\', $("#srp_password_new_1")[0].value, function(salt, verStr) {\
          $.post("/password.lp", { CSRFtoken:$("meta[name=CSRFtoken]").attr("content"), salt:salt, verifier:verStr,reminder:$("#reminder")[0].value },\
           function(data, textStatus) {\
             window.location="/";\
        });\
       });\
      }\
      srp.passwordchanged = function() {\
        var params = [];\
        params.push({\
            name : "action",\
            value : "PasswordChanged"\
        }, tch.elementCSRFtoken());\
        $.post("password.lp", params, function(){\
          window.location = "/";\
        });\
      }\
      srp.error_message = function() {\
\
           $("#erroruserpass_4").show();\
           $(".control-group").addClass("error");\
\
      }\
      srp.identify("/password", username, password);\
    });\
  })\
</script>\
</body>\
</html>\
'); 