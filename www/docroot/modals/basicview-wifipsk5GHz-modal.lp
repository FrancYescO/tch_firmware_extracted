--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session

local pathSec = "rpc.wireless.ap.@ap3.security."
local content_sec = {
  mode = pathSec .. "mode",
  wep_key = pathSec .. "wep_key",
  wpa_psk = pathSec .. "wpa_psk_passphrase",
}
content_helper.getExactContent(content_sec)

local  mapParams = {
  wifi_pswd_new1 = pathSec .. "wpa_psk_passphrase",
}

local gVSLIR = post_helper.getValidateStringLengthInRange
local vPSK = post_helper.validatePSK
local vWEP = post_helper.validateWEP

local function vPSWD(value, object, key)
  if  value == "********" then
    value = session:retrieve(key)
    object[key] = value
  else
    session:store(key, value)
  end

  if (content_sec.mode == "wep" and content_sec.wep_key ~= value)
     or (content_sec.mode ~= "wep" and content_sec.wpa_psk ~= value) then
    return nil, "Invalid current WiFi password"
  end
  return true
end

local function vNewPSWD(func, param)
  return function(value, object, key)
    if  value == "********" then
      value = session:retrieve(key)
      object[key] = value
    else
      session:store(key, value)
    end

    if param and value ~= object[param] then
        return nil, "The passwords do not match"
    end

    return func(value, object, key)
  end
end

local mapValid = {
  wifi_pswd = vPSWD,
  wifi_pswd_new1 = vNewPSWD(vPSK, "wifi_pswd_new2"),
  wifi_pswd_new2 = vNewPSWD(vPSK, "wifi_pswd_new1")
}

if content_sec.mode == "wep" then
  mapParams.wifi_pswd = pathSec .. "wep_key"
  mapValid.wifi_pswd_new1 = vNewPSWD(vWEP, "wifi_pswd_new2")
  mapValid.wifi_pswd_new2 = vNewPSWD(vWEP, "wifi_pswd_new1")
end

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

for k,v in pairs(helpmsg) do
    content[k] = ""
end

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
        <legend>');  ngx.print( T"Manage my wireless network" ); ngx.print('</legend>\
        ');  
          local infoclass = {
            alert = {
              class = "alert-info",
            }
          }
          local html={}
          html[#html + 1] = ui_helper.createAlertBlock(T"Action 4B: Change the password for my wireless network", infoclass)
          html[#html + 1] = ui_helper.createMessages(message_helper.popMessages())

          html[#html + 1] = '<div class="btn btn-primary btn-large" id="advshow">Modify wireless network password</div>'
          ngx.print(html)
          ngx.print('\
        <div id="adv" class="hide">\
          ');  
          local pswdclass = {
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
          html = {}
          html[#html + 1] = ui_helper.createInputPassword(T"Enter current WiFi password", "wifi_pswd", content["wifi_pswd"], pswdclass, helpmsg["wifi_pswd"])
          html[#html + 1] = ui_helper.createInputPassword(T"Enter new WiFi password", "wifi_pswd_new1", content["wifi_pswd_new1"], pswdclass, helpmsg["wifi_pswd_new1"])
          html[#html + 1] = ui_helper.createInputPassword(T"Confirm new WiFi password", "wifi_pswd_new2", content["wifi_pswd_new2"], pswdclass, helpmsg["wifi_pswd_new2"])
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
<script>\
    $(document).ready(function() {\
        if ($(".alert-error").length > 0) {\
            $(\'#adv\').show();\
            $(\'#advshow\').hide();\
        } else {\
           $(".modal-body input").val("");\
        }\
\
        $(".alert-success").text("Password modified successfully");\
\
        $(\'#advshow\').click(function(){\
            $(\'#adv\').show();\
            $(\'#advshow\').hide();\
            $(".alert-success").hide();\
        });\
    });\
</script>\
'); 