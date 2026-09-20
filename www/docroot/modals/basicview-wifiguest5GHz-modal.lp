--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")

local pathAP = "rpc.wireless.ap.@ap4."
local pathIf = "rpc.wireless.ssid.@wl1_1."

local content_sec = {
  mode = pathAP .. "security.mode",
}
content_helper.getExactContent(content_sec)

local  mapParams = {
  ap_enabled = pathAP .. "admin_state",
  ssid = pathIf .. "ssid",
  pswd = pathAP .. "security.wpa_psk_passphrase",
}

local vB = post_helper.validateBoolean
local vPSK = post_helper.validatePSK
local vWEP = post_helper.validateWEP
local gVSLIR = post_helper.getValidateStringLengthInRange

local mapValid = {
  ap_enabled = vB,
  ssid = gVSLIR(1,32),
  pswd = vPSK,
}

if content_sec.mode == "wep" then
  mapParams.pswd = pathAP .. "security.wep_key"
  mapValid.pswd = vWEP
end

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader("Guided View") ); ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="');  ngx.print( uri ); ngx.print('">\
    <div class="span4">\
      ');  
       local lp = require("web.lp")
       lp.setpath("/www/snippets/")
       lp.include("nav-basicview-actions.lp")
       ngx.print('\
    </div>\
    <div class="span7">\
      <fieldset>\
        <legend>');  ngx.print( T"Manage a guest access (second wireless network)" ); ngx.print('</legend>\
          ');  
          local infoclass = {
            alert = {
              class = "alert-info",
            }
          }
          local html={}
          html[#html + 1] = ui_helper.createAlertBlock(T"This allows you to provide a guest access with own name and password to your visitors (friends and family for instance) so that they have a WiFi access when they come to your home, without have access to your data or devices", infoclass)
          html[#html + 1] = ui_helper.createMessages(message_helper.popMessages())
          local switchclass = {
            label = {
              class = "long"
            },
            controls = {
              class = "long"
            },
          }

          html[#html + 1] = ui_helper.createSwitch(T"Activate/Deactivate your guest access", "ap_enabled", content["ap_enabled"], switchclass)
          local inputclass = {
            label = {
              class = "long"
            },
            controls = {
              class = "long"
            },
            input = {
              class= "span4",
            }
          }
          html[#html + 1] = ui_helper.createInputText(T"Choose a name for your guest access", "ssid", content["ssid"], inputclass, helpmsg["ssid"])
          html[#html + 1] = ui_helper.createInputText(T"Define a password", "pswd", content["pswd"], inputclass, helpmsg["pswd"])
          ngx.print(html)
          ngx.print('\
          <div class="pull-left">\
            <a href="/home.lp" class="btn btn-large">');  ngx.print( T"Cancel" ); ngx.print('</a>\
            &nbsp;\
            <div id="save-config" class="btn btn-primary btn-large">');  ngx.print( T"Confirm" ); ngx.print('</div>\
          </div>\
        </div>\
    </fieldset>\
  </form>\
</div>\
'); 