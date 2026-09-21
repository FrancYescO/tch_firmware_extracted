--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local web = require("web.web")
local session = ngx.ctx.session
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "GatewayPage", "gateway")

local changePwd = T"Change Password"
local now = T"Now"
local remindLater = T"Remind me later"
local dontRemind = T"Do not remind me again"

if post_helper.getVariantValue(variantHelper, "accessKey") then
  changePwd = T"Change Access Key"
end
if post_helper.getVariantValue(variantHelper, "passwordReminder") then
  changePwd = T"Login Password"
end
  ngx.print('\
\
<!DOCTYPE HTML>\
<body>\
<div class="container">\
 ');  if not session:isdefaultuser() and not session:retrieve("password_reminder_shown") and session:getusername() ~= assistant:username() and  post_helper.getVariantValue(variantHelper, "changePassword") then
      local result = content_helper.getMatchedContent("uci.web.user.", {name = session.getusername()})
      if result and result[1].password_reminder ~= "0" then
        local html = {}
        html[#html + 1] = '<div class="modal fade in" id="password_reminder">'
        html[#html + 1] = ui_helper.createHeader(changePwd)
        html[#html + 1] = '<div class="modal-body update">'
        html[#html + 1] = '<form class="form-horizontal" method="post" action="gateway.lp">'
        html[#html + 1] = ui_helper.createSimpleInputHidden("CSRFtoken", session:getCSRFtoken())
        if post_helper.getVariantValue(variantHelper, "passwordReminder") then
	  html[#html + 1] = "<fieldset><legend>" .. T"Warning: current login password is the default one. It is strongly recommended to change it in order to enforce the security." .. "</legend>"
	end
        html[#html + 1] = '<fieldset>'
        local attr = {radio = {style = "display: block"}}
        if post_helper.getVariantValue(variantHelper, "passwordReminder") then
          html[#html + 1] = ui_helper.createInputRadio("", "passwordchange", {{"now", now},{"remindlater", remindLater}},nil,attr)
        else
          html[#html + 1] = ui_helper.createInputRadio("", "passwordchange", {{"now", now},{"remindlater", remindLater},{"dontremind", dontRemind}},nil,attr)
        end
        html[#html + 1] = '</fieldset>'
        html[#html + 1] = '</form>'
        html[#html + 1] = '</div>'
        html[#html + 1] = ui_helper.createFooter()
        html[#html + 1] = '</div>'
        ngx.print(html)  ngx.print('\
        <script src="/js/change-access-key.js"></script>\
      ');  end
      session:store("password_reminder_shown", true)
    end  ngx.print('\
  </div>\
</body>\
</html>\
'); 