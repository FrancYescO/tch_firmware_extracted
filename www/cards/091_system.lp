<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local session = ngx.ctx.session
local modalPath = "/modals/system-modal.lp"

syslog_present = "Disabled"

local Syslog_IGD = proxy.get("InternetGatewayDevice.X_000E50_Syslog.LogIP","InternetGatewayDevice.X_000E50_Syslog.LogFilterIP")
if Syslog_IGD[1].value ~= "" or Syslog_IGD[2].value ~= "" then 
   syslog_present = "Enabled"
end

local state_map = {
    Disabled = T"Syslog Disabled",
    Enabled = T"Syslog Enabled",
}

local light_map = {
  Disabled = "off",
  Enabled = "green",
}

local debug = 0
local args = ngx.req.get_uri_args()
if args then
  for key, val in pairs(args) do
    if key=="debug"  then debug = 1  end
  end
end

if not session:isdefaultuser() and debug == 1 then
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
end
%>

