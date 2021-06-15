--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-parental')
local session = ngx.ctx.session
local role = session:getrole()
local untaint = string.untaint

local triesbeforemsg = 3
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  timestamp = "uci.version.version.@version[0].timestamp",
}
content_helper.getExactContent(cui)
local year= cui.timestamp
local current_year = (string.sub(year,1,4))

  ngx.print('\
');  
  string.format('<html lang="%s">', gettext.language())
  local html = {}
  html[#html + 1] = '<head>'
  html[#html + 1] = '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
  html[#html + 1] = '<meta charset="UTF-8">'
  html[#html + 1] = '<meta name="CSRFtoken" content="'..ngx.ctx.session:getCSRFtoken()..'">'
  html[#html + 1] = '<link href="/css/gw.css" rel="stylesheet">'
  html[#html + 1] = '<link href="/css/responsive.css" rel="stylesheet">'
  html[#html + 1] = '<script src="/js/main-min.js" ></script>'
  html[#html + 1] = '<script src="/js/srp-min.js" ></script>'
  html[#html + 1] = '<title>'..T"Parental Blocked"..'</title>'
  html[#html + 1] = '</head>'
  html[#html + 1] = '<body>'
  html[#html + 1] = '<div class="container">'
  html[#html + 1] = '<div class="row">'
  html[#html + 1] = '<div class="header span12">'
  html[#html + 1] = '<a href="'..untaint(cui.nsplink)..'" target="_blank"><img src="/img/logo.gif" style="max-height:67.5px"></a>'
  html[#html + 1] = '</div></div>'
  html[#html + 1] = '<div class="row">'
  html[#html + 1] = '<div class="offset4 span4">'
  html[#html + 1] = '<p><strong>'..T"Destination is blocked due to parental control."..'</strong></p>'
  html[#html + 1] = '<p><a href="http://'..untaint(ngx.var.server_addr)..'">'..T"Continue to the main page."..'</a></p>'
  html[#html + 1] = '</div></div>'
  html[#html + 1] = '<div class="row"><div class="copyright span12"><p>&copy; Technicolor '..untaint(current_year)..'</p></div></div>'
  html[#html + 1] = '</div>'
  html[#html + 1] = '</body>'
  ngx.print(html)
  ngx.print('\
'); 