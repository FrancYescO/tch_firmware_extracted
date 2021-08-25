--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local triesbeforemsg = 0
local content_helper = require("web.content_helper")
local proxy = require("datamodel")

local cui = {
  s_defaultuser = "uci.web.sessionmgr.@default.default_user",
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  adusrname = "uci.web.user.@usr_admin.name",
  legacysalt = "uci.web.user.@usr_admin.legacy_salt",
  timestamp = "uci.version.version.@version[0].timestamp",
}
content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year,1,4))

local currentuser = ngx.ctx.session:getusername()
local getargs = ngx.req.get_uri_args()
local dm = require("datamodel")
local string = string
local format = string.format

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "redirect" then
  local ipaddr = ""
  if ngx.req.get_uri_args().param == "system_reset" then
    ipaddr = proxy.get("uci.ucidefaults.interface.@lan_reset.ipaddr")[1].value
  else
    ipaddr = proxy.get("uci.network.interface.@lan.ipaddr")[1].value
  end
  ngx.header.content_type = "application/json"
  ngx.print(json.encode(ipaddr))
  ngx.exit(ngx.HTTP_OK)
end

local lastaccess = {
  user = "" ,
  time = "",
  clientIp = ""
}

local function writeState(lastAccess)
  local f = io.open("/etc/lastaccess", "w")
  if f then
    for key, value in pairs(lastAccess) do
      f:write(format("%s=%s\n", key, value))
    end
    f:close()
  end
end

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "lastaccess" then
  lastaccess.user = ngx.ctx.session:getusername()
  lastaccess.clientIp = ngx.var.remote_addr
  lastaccess.time = os.date("%T", os.time())
  writeState(lastaccess)
  local login_count = proxy.get("uci.web.uiconfig.@uidefault.logincount")[1].value
  if login_count == "10000" then
    proxy.set("uci.web.uiconfig.@uidefault.logincount","1")
  else
    proxy.set("uci.web.uiconfig.@uidefault.logincount", tostring(login_count + 1))
  end
  proxy.apply()
end

if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  local ret = false

  --if the post is to reset password, it means the legacy_salt should be reset
  if post_args.resetpass then
    ret = ngx.ctx.session:changePassword(post_args.salt, post_args.verifier)
    if ret then
      dm.set("uci.web.user.@usr_admin.legacy_salt", "")
      dm.apply()
    end
  end

  if post_args.do_signout then
    --NG-9496:In Advanced UI，the signout doesn't works.
    --The param from=adv comes from action.js
    if getargs.from == "adv" then  --User click signout in Advanced UI (cards)
      --Clear the current session
      ngx.ctx.session:logout()
      if cui.s_defaultuser ~= "" then
        --default user exists, access the advanced WEBUI with default user.
        ngx.redirect("/gateway.lp")
      else
        --store the "/gateway.lp" and then redirect to "/login.lp",
        --and redirect ot "/gateway.lp" after authentication
        ngx.ctx.session:store("lasturi", "/gateway.lp")
        --Show the uri without variable.
        ngx.redirect("/login.lp")
      end
    else  --User clicks the signout in RefreshUI.
      --if we changed the default user to non default user,the s_defaultuser will be null
      if cui.s_defaultuser ~= "" then
        --Non default usr restored to the default user, and later click logout.
        --The session temporary data need to be cleared.
        if currentuser ~= cui.s_defaultuser then
          ngx.ctx.session:logout()
        end
        --default user needn't to login, so we redirect to home page.
        ngx.redirect("/")
      else
        --the default user is NOT admin, the logout will redirect to login page (handled in action.js),
        --the session temporary data will be cleared here.
        ngx.ctx.session:logout()
      end
    end
  end
end

--NG-8926:After Signing in on the advaned user page you should be redirected to the Advance GUI
--The user clicked the SIGNIN in advanced UI,
--Store the "/gateway.lp" temporary,
--And redirect to "gateway.lp" after authentication.
if ngx.req.get_method() == "GET" then
  if getargs.from == "adv" then
    --store the "/gateway.lp" and then redirect to "/login.lp"
    ngx.ctx.session:store("lasturi", "/gateway.lp")
    ngx.redirect("/login.lp")
  end
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
    <title>');  ngx.print( T"Login" ); ngx.print('</title>\
</head>\
<body>\
  <div class="container">\
    <div class="logo-technicolor"><img src="/img/logo.gif"></div>\
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
            <div id="defaultpassword" class="alert alert-info hide">\
                ');  ngx.print( T"If you haven't changed it, the default password can be found on the sticker under your gateway (it's called <strong>\"access code\"</strong>)" ); ngx.print('\
            </div>\
            <div class="pull-right"><div id="sign-me-in" class="btn btn-primary btn-large">');  ngx.print( T"Sign in" ); ngx.print('</div></div>\
          </fieldset>\
        </form>\
      </div>\
      </div>\
    </div>\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
  </div>\
<script>\
$(document).ready(\
  function() {\
    var triesbeforemsg = ');  ngx.print( triesbeforemsg ); ngx.print(';\
    var tries = 0;\
    var password = "";\
    var tmppassword = "";\
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
      password = $("#srp_password")[0].value;\
      tmppassword = password;\
\
      //to get the legacy_salt & is not null, and confirm the username is adminusername, do migration\
      var legacysalt = "');  ngx.print( cui.legacysalt ); ngx.print('";\
      var aduser = "');  ngx.print( cui.adusrname ); ngx.print('";\
      if (("" != legacysalt) && (aduser == $("#srp_username")[0].value))\
      {\
          var hashObj = new jsSHA((legacysalt+tch.stringToHex(password)), "HEX");\
          password = hashObj.getHash("SHA-1", "HEX");\
      }\
      var srp = new SRP();\
      srp.success = function() {\
        //when do migration the legacy_salt is null and current user is admin, do the reset pass operation\
        if (("" != legacysalt) && (aduser == $("#srp_username")[0].value))\
        {\
          srp.generateSaltAndVerifierTheCallback($("#srp_username")[0].value, tmppassword, function(salt, verStr) {\
            $.post("/login.lp", { CSRFtoken:$("meta[name=CSRFtoken]").attr("content"), salt:salt, verifier:verStr, resetpass:"1" },\
              function reloadPage(){\
                if (window.location.pathname.search(/\\/login\\.lp$/) == -1)\
                  window.location.reload();\
                else\
                  window.location = "/";\
              });\
          });\
        }\
        $.get("/login.lp", {action:"lastaccess"}, function (data){\
          pathLoad();\
        });\
        function pathLoad() {\
          if (window.location.pathname.search(/\\/login\\.lp$/) == -1){\
            var curl = window.location.href\
            window.location.href = curl.substring(0,curl.indexOf("#"));\
          }else\
            window.location = "/";\
        }\
      }\
      srp.error_message = function() {\
        $("#sign-me-in").text(\'');  ngx.print( T"Sign in" ); ngx.print('\');\
        $("#erroruserpass").show();\
        $(".control-group").addClass("error");\
\
        tries++;\
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {\
            $("#defaultpassword").show();\
        }\
      }\
      srp.identify("/authenticate", $("#srp_username")[0].value, password);\
    });\
  })\
</script>\
</body>\
</html>\
'); 