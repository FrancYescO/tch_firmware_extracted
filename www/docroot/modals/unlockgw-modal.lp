--pretranslated: do not change this file
 
--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")

local unlockedStatus = proxy.get("rpc.env.var.unlockedstatus")[1].value
local unlockGUIbutton = proxy.get("rpc.env.var.unlockGUIbutton")[1].value

if ngx.req.get_method() == "POST" and unlockGUIbutton == "1" then
  local postArgs = ngx.req.get_post_args()
  if postArgs.action == "unlock_gw" then
    proxy.set("rpc.env.var.unlockedstatus", "1")
    ngx.header.content_type = "application/json"
    ngx.print('{ "success":"true" }')
    ngx.timer.at(0, function()
      proxy.apply()
    end)
    ngx.exit(ngx.HTTP_OK)
  end
end
  ngx.print('\
');  ngx.print( ui_helper.createHeader(T"Enhanced configuration", false, false) ); ngx.print('\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/unlockgw-modal.lp">\
    ');  ngx.print( ui_helper.createMessages(message_helper.popMessages()) ); ngx.print('\
    ');  
      local unlock_button = {
        button = {
          id = "btn-unlock"
        }
      }
      local switch_alert = {
        alert = {
          id = "switch_alert",
          class = "hide"
        }
      }

      local html = {}
      if unlockedStatus == "0" then
        html[#html + 1] = "<fieldset><legend>" .. T"Enabling Modem enhanced configuration" .. "</legend>"
        html[#html + 1] = ui_helper.createButton(T"Enhanced configuration", T"Enable", "icon-ok-sign", unlock_button)
        html[#html + 1] = ui_helper.createAlertBlock(T"Warning! This procedure enables the access to configuration parameters that, if modified, may prejudice Gateway interoperability with TIM network and support. The procedure will be traced by TIM for technical support reasons. The unlocking can be reverted in any moment and the Gateway interoperability will be restored by executing a Reset to Factory Default.</br></br>Note: In case you want to unlock the Gateway, for security reasons the Password will be set to the Access Key as shown on the Label of the Gateway</br></br>If you want to continue, press Save. If not, press Cancel!", switch_alert)
      else
        html[#html + 1] = ui_helper.createAlertBlock(T"You have to sign in again. Please wait you will be redirected to the Sign in page in 20 seconds or click close.")
      end
      ngx.print(html)
      ngx.print('\
  </form>\
</div>\
<script src="/js/unlockgw-modal.js"></script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 