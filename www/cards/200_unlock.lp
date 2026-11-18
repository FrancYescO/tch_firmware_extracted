--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session
local proxy = require("datamodel")

local showUnlock = proxy.get("uci.env.var.unlockGUIbutton")[1].value
local unlockState = proxy.get("uci.env.var.unlockedstatus")[1].value
local openModal

if unlockState == "0" then
	openModal = "modals/unlock-modal.lp"
else
	openModal = ""
end

if session:hasAccess("/modals/unlock-modal.lp") and showUnlock == "1" then
  ngx.print('\
\
<div class="span3">\
    <div class="smallcard">\
        ');  ngx.print( ui_helper.createCardHeader(T"Unlock Gateway", openModal) ); ngx.print('\
        <div class="content">\
            <p class="subinfos">\
		<strong>\
		   ');  
			if unlockState == "0" then
				ngx.print(T"Enable Modem configuration for accessing to non-TIM network");
			else
				ngx.print(T"The Gateway is in unlocked state and is ready to be configured for use on non-TIM networks");
			end
		   ngx.print('<br>		      \
		</strong>\
            </p>\
        </div>\
    </div>\
</div>\
\
');  
end
  ngx.print('\
'); 