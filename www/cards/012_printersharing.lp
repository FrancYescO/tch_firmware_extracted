<%
local istainted = string.istainted

-- Enable localization
gettext.textdomain('webui-printersharing')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local attributes = { span = { class = "span4" } }
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local modalPath = nil
if session:hasAccess("/modals/printersharing-modal.lp") then
  modalPath = "/modals/printersharing-modal.lp"


local content = {
  printersharing_enabled = "uci.printersharing.config.enabled"
}
content_helper.getExactContent(content)

local printersharing_state = T"Printer sharing disabled"
if content["printersharing_enabled"] == "1" then
  printersharing_state = T"Printer sharing enabled"
end

%>

<div class="span3">
  <div class="smallcard">
    <%=ui_helper.createCardHeader(T"Printer Sharing", modalPath, nil, nil) %>
    <div class="content">
      <%=ui_helper.createSimpleLight(content["printersharing_enabled"], printersharing_state, attributes)%>
    </div>
  </div>
</div>

<%
end
%>
