--pretranslated: do not change this file
 
-- NG-78566
-- Enable localization
gettext.textdomain('webui-parental')

local triesbeforemsg = 3
local content_helper = require("web.content_helper")

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
}
content_helper.getExactContent(cui)

  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
<head>\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <link href="/css/gw.css" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
	<link href="/css/TIM.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <script src="/js/srp-min.js" ></script>\
    <title>');  ngx.print( T"Parental Blocked" ); ngx.print('</title>\
</head>\
<body>\
  <div class="container">\
    <div class="row">\
      <div class="header span12">\
	<img class="timlogo" src="/img/TIM.png">\
      </div>\
    </div>\
    <div class="row">\
      <div class="offset4 span4">\
        <p><strong>');  ngx.print( T"Destination is blocked due to parental control." ); ngx.print('</strong></p>\
        <p><a href="http://');  ngx.print(ngx.var.server_addr); ngx.print('">');  ngx.print( T"Continue to the main page." ); ngx.print('</a></p>\
      </div>\
    </div>\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor 2018</p></div></div>\
  </div>\
</body>\
</html>\
'); 