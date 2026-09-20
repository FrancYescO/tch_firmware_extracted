--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local gVSLIR = post_helper.getValidateStringLengthInRange

local mapParams = {
  ssid = "rpc.wireless.ssid.@wl1.ssid"
}

local mapValid = {
  ssid = gVSLIR(1,32),
}

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
        <legend>');  ngx.print( T"Manage my wireless network" ); ngx.print('</legend>\
        ');  
          local infoclass = {
            alert = {
              class = "alert-info",
            }
          }
          local labelclass = {
            label = {
              class = "long"
            },
            controls = {
              class = "long"
            },
            span = {
              class = "span4"
            }
          }
          local html={}
          html[#html + 1] = ui_helper.createAlertBlock(T"Action 4A: Personlize the name of my wireless network (WiFi SSID)", infoclass)
          html[#html + 1] = ui_helper.createMessages(message_helper.popMessages())
          html[#html + 1] = ui_helper.createLabel(T"Current wireless network name", content["ssid"], labelclass)
          html[#html + 1] = '<div class="btn btn-primary btn-large" id="advshow">Change wireless network name</div>'
          ngx.print(html)
          ngx.print('\
        <div id="adv" class="hide">\
          ');  
          local inputclass = {
            label = {
              class = "long"
            },
            controls = {
              class = "long"
            },
            input = {
              pattern= "[!-~][ -~]{0,30}[!-~]",
              maxlength= "32",
              class= "span4",
            }
          }
          html = {}
          html[#html + 1] = ui_helper.createInputText("New wireless network name", "ssid", content["ssid"], inputclass, helpmsg["ssid"])
          ngx.print(html)
            ngx.print('\
          <div class="pull-left">\
            <a href="/" class="btn btn-large">');  ngx.print( T"Cancel" ); ngx.print('</a>\
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
        };\
\
        $(\'#advshow\').click(function(){\
            $(\'#adv\').show();\
            $(\'#advshow\').hide();\
            $(".alert-success").hide();\
        });\
    });\
</script>\
'); 