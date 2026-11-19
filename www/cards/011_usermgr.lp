--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session
local usersValue = session:getusername()
local usersLabel = T"Active User"
local post_helper = require("web.post_helper")

if session:hasAccess("/modals/usermgr-modal.lp") then
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Management", "modals/usermgr-modal.lp") ); ngx.print('\
    ');  if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
    <div class="content">\
    ');  else   ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf0c0;">\
    ');  end   ngx.print('\
      <p class="subinfos">');  ngx.print(usersLabel); ngx.print(': <strong>');  ngx.print(usersValue); ngx.print('</strong></p>\
    </div>\
  </div>\
</div>\
\
');  
end
  ngx.print('\
'); 