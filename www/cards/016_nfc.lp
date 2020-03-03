--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-nfc')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local content_nfc = {
  enabled = "rpc.nfc.enabled",
}
content_helper.getExactContent(content_nfc)

local nfclight = "0"
local nfc_enabled = T"NFC Disabled"

if content_nfc["enabled"] == "true" then
  nfclight = "1"
  nfc_enabled = T"NFC Enabled"
end

local modalPath = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/nfc-modal.lp") then
    modalPath = "/modals/nfc-modal.lp"
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print(ui_helper.createCardHeaderNoIcon(T"NFC", modalPath, nil, nil) ); ngx.print('\
    <div class="content">\
      ');  ngx.print( ui_helper.createSimpleLight(nfclight, nfc_enabled) ); ngx.print('\
    </div>\
  </div>\
</div>\
'); 