--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local ngx = ngx
local modal = '/modals/unlockgw-modal.lp'
local session = ngx.ctx.session
local ispUser = session:hasAccess(modal)
local content_helper = require("web.content_helper")
local ui_helper = require 'web.ui_helper'

local content = {
  UnlockedStatus = "rpc.env.var.unlockedstatus",
  GUIbuttonVisible = "rpc.env.var.unlockGUIbutton"
}
content_helper.getExactContent(content)

if content.UnlockedStatus == "0" then
  modal = '/modals/unlockgw-modal.lp'
else
  modal = ""
end

local unlocked_state = T"Enable modem configuration for accessing to non-TIM network"
if content.UnlockedStatus == "1" then
  unlocked_state = T"Gateway is in unlocked state and is ready to be configured for use on non-TIM networks"
end

if ispUser and content.GUIbuttonVisible == "1" then   ngx.print('\
  <div class="span3">\
    <div class="smallcard">\
      ');  if ispUser then
        ngx.print(ui_helper.createCardHeader(T"Unlock Gateway", modal))
      end   ngx.print('\
        <div class="content">\
          ');  ngx.print(ui_helper.createSimpleLight(content.UnlockedStatus, unlocked_state))   ngx.print('\
        </div>\
    </div>\
  </div>\
');  end
  ngx.print('\
\
'); 