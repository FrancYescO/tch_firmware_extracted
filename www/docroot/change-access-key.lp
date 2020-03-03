--pretranslated: do not change this file
 ngx.print('\
');  
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local web = require("web.web")
local session = ngx.ctx.session
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')

  ngx.print('\
<!DOCTYPE HTML>\
<body>\
  <div class="container">\
    ');  if not session:isdefaultuser() and not session:retrieve("password_reminder_shown") and session:getusername() ~= assistant:username() then
      local result = content_helper.getMatchedContent("uci.web.user.", {name = session.getusername()})
      if result and result[1].password_reminder ~= "0" then
        html = {}
        html[#html + 1] = '<div class="modal fade in" id="password_reminder">'
        html[#html + 1] = ui_helper.createHeader(T"Change Access Key")
        html[#html + 1] = '<div class="modal-body update">'
        html[#html + 1] = '<form class="form-horizontal" method="post" action="gateway.lp">'
        html[#html + 1] = ui_helper.createSimpleInputHidden("CSRFtoken", session:getCSRFtoken())
        html[#html + 1] = '<fieldset>'
        local attr = {radio = {style = "display: block"}}
        html[#html + 1] = ui_helper.createInputRadio("", "passwordchange", {{"now", T"Now"},{"remindlater", T"Remind me later"},{"dontremind", T"Do not remind me again"}},nil,attr)
        html[#html + 1] = '</fieldset>'
        html[#html + 1] = '</form>'
        html[#html + 1] = '</div>'
        html[#html + 1] = ui_helper.createFooter()
        html[#html + 1] = '</div>'
        ngx.print(html)  ngx.print('\
        <script>\
          $("#password_reminder").modal();\
          $("#save-config").click(function(){\
            var value = $("input[name=passwordchange]:checked").val();\
            if(value == "now"){\
               window.location = "/password.lp";\
            }else if(value == "remindlater"){\
               $("#password_reminder").modal(\'hide\');\
            }else if(value == "dontremind"){\
               $("#password_reminder form").submit();\
            }\
            return false;\
          });\
        </script>\
      ');  end
      session:store("password_reminder_shown", true)
    end  ngx.print('\
  </div>\
</body>\
</html>\
'); 