--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-parental')

local triesbeforemsg = 3
local content_helper = require("web.content_helper")
local format = string.format

function split(x, sep)
        local sep, fields = sep or ":", {}
        local pattern = format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

local cui = {
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
local imgpath = "/img/"
if lfs.attributes("/www/docroot/img/custom/logo.gif", "mode") == "file" then
  imgpath = "/img/custom/"
  logo_present = 1
end

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
}
content_helper.getExactContent(cui)

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
    <link href="/css/httpi.css" rel="stylesheet">\
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
        <a href="', cui.nsplink, '" target="_blank"><img class="logo" src="', imgpath, 'logo.gif"></a>\
      </div>\
    </div>\
    <div class="row">\
      <div class="offset4 span4">\
        <p><strong>');  ngx.print( T"Destination is blocked due to parental control." ); ngx.print('</strong></p>\
        <p><a href="http://');  ngx.print(ngx.var.server_addr); ngx.print('">');  ngx.print( T"Continue to the main page." ); ngx.print('</a></p>\
      </div>\
    </div>\
	    <div class="copyright span12">\
		    <p>&copy; Technicolor ',current_year, '</p>\
		    <p>', format(T"Software Version: %s",version), '</p>\
   	  </div>\
    </div>\
  </div>\
</body>\
</html>\
'); 