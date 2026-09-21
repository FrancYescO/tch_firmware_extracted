<%
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local session = ngx.ctx.session
local format = string.format
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local modalPath = "/modals/system-modal.lp"
syslog_present = "Disabled"

local Syslog = proxy.get("uci.system.system.@system[0].ip", "uci.system.system.@system[0].filter_ip")
if Syslog and (Syslog[1].value ~= "" or Syslog[2].value ~= "") then
    syslog_present = "Enabled"
end
    local state_map = {
      Disabled = T"syslog Disabled",
      Enabled = T"syslog Enabled",
    }

    local light_map = {
      Disabled = "off",
      Enabled = "green",
    }

    if session:hasAccess("/modals/system-modal.lp") then
    local modal_link = format("class=\"modal-link\" data-toggle=\"modal\" data-remote=\"%s\" data-id=\"device-modal\"",modalPath)
%>
<div class="span3">
  <div class="smallcard">
    <%= ui_helper.createCardHeader(T"System Extras", modalPath) %>
    <div class="content card_bg" data-bg-text="&#xf0ad;">
      <div class="divtable">
        <%= ui_helper.createSimpleLight(nil, state_map[syslog_present], { light = { class = light_map[syslog_present] } }) %>
      </div>
    </div>
  </div>
</div>
<%
    end -- end for the second if
%>
