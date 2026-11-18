<%
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    modalPath = "/modals/internet-modal.lp"
end
%>

<%= ui_helper.createCardHeader(T"Internet Access", modalPath) %>
<div class="content">
  <p class="subinfos">
    <%= T("Gateway in bridge mode") %>
  </p>
</div>
