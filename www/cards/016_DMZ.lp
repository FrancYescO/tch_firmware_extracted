<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

-- WAN services data
local wan_services_data = {
  dmz_enable = "rpc.network.dmz.enabled",
}
content_helper.getExactContent(wan_services_data)

local session = ngx.ctx.session
if session:hasAccess("/modals/dmz-modal.lp") then
    local dmzstate
    local dmzled
    if wan_services_data["dmz_enable"] == "1" then
      dmzstate = T"DMZ enabled"
      dmzled = "1"
    else
      dmzstate = T"DMZ disabled"
      dmzled = "0"
    end
%>

<div class="span3">
  <div class="smallcard">

    <%= ui_helper.createCardHeader(T"DMZ", "modals/dmz-modal.lp") %>

    <div class="content">
    <% ngx.print(
            ui_helper.createSimpleLight(dmzled, dmzstate),
            '<p></p>'
        )
    %>
    </div>
  </div>
</div>
<%
end
%>
