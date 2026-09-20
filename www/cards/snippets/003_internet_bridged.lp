--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local modalPath = nil
local telstra_helper = require("telstra_helper")
local symbolv1 = telstra_helper.symbolnamev1

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    modalPath = "/modals/internet-modal.lp"
end
  ngx.print('\
\
\
  <p class="subinfos">\
    ');  ngx.print( T(symbolv1 .. " in bridge mode") ); ngx.print('\
  </p>\
'); 