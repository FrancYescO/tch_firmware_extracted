--pretranslated: do not change this file
 
local istainted = string.istainted

-- Enable localization
gettext.textdomain('webui-printersharing')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local attributes = { span = { class = "span4" } }
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local modalPath = nil
if session:hasAccess("/modals/printersharing-modal.lp") then
  modalPath = "/modals/printersharing-modal.lp"


local content = {
  printersharing_enabled = "uci.printersharing.config.enabled"
}
content_helper.getExactContent(content)

local printersharing_state = T"Printer sharing disabled"
if content["printersharing_enabled"] == "1" then
  printersharing_state = T"Printer sharing enabled"
end

  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeaderNoIcon(T"Printer Sharing", modalPath) ); ngx.print('\
    <div class="content">\
      ');  ngx.print(ui_helper.createSimpleLight(content["printersharing_enabled"], printersharing_state, attributes)); ngx.print('\
    </div>\
  </div>\
</div>\
\
');  
end
  ngx.print('\
'); 