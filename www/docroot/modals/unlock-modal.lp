--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local string, ngx, os = string, ngx, os
local tonumber = tonumber
local format, match = string.format, string.match
local gOrV = post_helper.getOrValidation
local vSIDN = post_helper.validateStringIsDomainName

local vb = post_helper.validateBoolean
local tabParam = {unlockState = "rpc.env.var.unlockedstatus"}

local tabVali = {unlockState = vb}

local content, helpmessage =  post_helper.handleQuery(tabParam, tabVali)

  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Unlock Gateway", false, false) ); ngx.print('\
<div class="modal-body update">\
');
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/unlock-modal.lp">\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
\
	');  
		html = {}
		local vlanswitchclass = {
		   input = {
			 class = "monitor-changes"
		   },
		   values = {on = "1", off = "0"},
		}
		
		 local vlanidclass = {
			alert = {
				class =string.format("monitor-unlockState monitor-%s","1"),
			},
		}
		if content["unlockState"] == "0" then
			html[#html + 1] = ui_helper.createAlertBlock(T"Enable Modem configuration for accessing to non-TIM network")
			html[#html + 1] = ui_helper.createSwitch(T"Unlock", "unlockState", content["unlockState"], vlanswitchclass)
			html[#html + 1] = ui_helper.createAlertBlock(T"Warning! This procedure enables the access to configuration parameters that, if modified, may prejudice Gateway interoperability with TIM network. The procedure will be traced by TIM for technical support reasons. The unlocking can be reverted in any moment and the Gateway interoperability will be restored by executing a Reset to Factory Default.",vlanidclass)
			html[#html + 1] = ui_helper.createAlertBlock(T"Note: In case you want to unlock the Gateway, for security reasons the Password will be set to the Access Key as shown on the Label of the Gateway",vlanidclass)
			html[#html + 1] = ui_helper.createAlertBlock(T"If you want to continue, press Save. If not, press Cancel!",vlanidclass)
		else
			html[#html + 1] = ui_helper.createAlertBlock(T"You have to sign in again. Please wait you will be redirected to the Sign in page in 20 seconds or click close.")
		end
	  
		ngx.print(html); ngx.print('\
  </form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); ngx.print('\
<script language ="javascript">\
	$("#save-config").click(function() {\
		setTimeout(function(){location.reload();},20000)\
});\
</script>\
\
');