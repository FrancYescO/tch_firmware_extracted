--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-fon')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local content_fon = {
  status = "uci.hotspotd.state.status"
}
content_helper.getExactContent(content_fon)

local fonlight = "0"
local fonstate = T"Telstra Air down"

if content_fon["status"] == "up" then
  fonlight = "1"
  fonstate = T"Telstra Air up"
end

local modalPath = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/fon-modal.lp") then
    modalPath = "/modals/fon-modal.lp"
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print(ui_helper.createCardHeaderNoIcon(T"Telstra Air", modalPath, nil, nil) ); ngx.print('\
    <div class="content">\
      ');  ngx.print( ui_helper.createSimpleLight(fonlight, fonstate) ); ngx.print('\
    </div>\
  </div>\
</div>\
'); 