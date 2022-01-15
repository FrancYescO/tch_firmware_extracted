--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local untaint = string.untaint
local proxy = require("datamodel")
local tprint = require("tch.tableprint")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local table, ipairs, istainted, format = table, ipairs, string.istainted, string.format
local login_side = nil
local cui = {
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  timestamp = "uci.version.version.@version[0].timestamp",
  sshenable = "uci.dropbear.dropbear.@lan.enable",
}
local mapValid = {
    sshenable = post_helper.validateBoolean,
}
local content, helpmsg = post_helper.handleQuery(cui, mapValid)
local year= content.timestamp
local current_year = (string.sub(year,1,4))
local switchAttr = {
  values = {
    on = "1",
    off = "0"
  }
}
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
    <title>');  ngx.print( T"SSH Access" ); ngx.print('</title>\
\
</head>\
<body>\
  <div class="container">\
    <div class="logo-technicolor"><a href="');  ngx.print( content.nsplink ); ngx.print('" target="_blank"><img src="/img/logo.gif"></a></div>\
    <div class="row">\
      <div class="offset4 span4">\
        <div class="login">\
        <form class="form-horizontal">\
          <fieldset>\
                <h2>');  ngx.print( T"SSH Access" ); ngx.print('</h2>\
\
            ');  ngx.print( ui_helper.createSwitch(T"SSH Enabled", "Allow-SSH", content["sshenable"], switchAttr, helpmsg["sshenable"]) ); ngx.print('\
            <div class="pull-right"><br>\
                <a href="/" class="btn btn-primary btn-large">');  ngx.print( T"Return" ); ngx.print('</a>\
                &nbsp;\
                <div id="enable-ssh" class="btn btn-primary btn-large">');  ngx.print( T"Save" ); ngx.print('</div>\
            </div>\
          </fieldset>\
        </form>\
      </div>\
      </div>\
    </div>\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor ');  ngx.print(current_year); ngx.print('</p></div></div>\
    </div>\
  <script>\
    $("#enable-ssh").on("click", function () {\
      var token = $("meta[name=CSRFtoken]").attr("content");\
      var params = [ {name : "action", value : "SAVE"},\
        {name : "CSRFtoken", value : token }\
      ];\
      var a = $("#Allow-SSH").val();\
      params.push({name:"sshenable",value: a});\
      $.post("/ssh-access.lp", params, function (data) {\
        alert("');  ngx.print( T"Changes saved correctly" ); ngx.print('");\
      }).fail(function (jqXHR) {\
        alert("');  ngx.print( T"Error applying the changes" ); ngx.print('");\
      });\
    });\
  </script>\
</body>\
</html>\
'); 