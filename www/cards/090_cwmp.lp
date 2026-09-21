<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local session = ngx.ctx.session
local modalPath = "/modals/cwmp-modal.lp"



local debug = 0
local args = ngx.req.get_uri_args()
if args then
  for key, val in pairs(args) do
    if key=="debug"  then debug = 1  end
  end
end


if not session:isdefaultuser() and debug == 1 then

local content = {
      cwmp_url              = "uci.cwmpd.cwmpd_config.acs_url",
      cwmp_state            = "uci.cwmpd.cwmpd_config.state",
      cwmp_periodic         = "uci.cwmpd.cwmpd_config.periodicinform_interval",
}

content_helper.getExactContent(content)

local CWMP_en = format("%s", content.cwmp_state) -- untaint 
local CWMP_State = "Disabled"
if CWMP_en == "1" then
   CWMP_State = "Enabled"
end

local state_map = {
    Disabled = T"Disabled",
    Enabled = T"Enabled",
}

local light_map = {
  Disabled = "off",
  Enabled = "green",
}

local switchName = "cwmp_state"

local txt = T"Not Set"
if content["cwmp_url"] ~= "" then
   txt = content["cwmp_url"] 
end
%>

<div class="span3">
    <div class="smallcard">
        <%= ui_helper.createCardHeader(T"CWMP", modalPath, switchName, CWMP_en) %>
        <div class="content card_bg" data-bg-text="&#xf0ad;">
        <div class="divtable">
            <%= ui_helper.createSimpleLight(nil, state_map[CWMP_State], { light = { class = light_map[CWMP_State] } }) %>
            <p class="subinfos">
            <%
               ngx.print(format("%s : <strong>%s</strong>",T"ACS URL",txt))
            %>
            </p>
            <p class="subinfos">
            <%
               ngx.print(format("%s : <strong>%s</strong>",T"Periodic",content["cwmp_periodic"] ))
            %>
            </p>
         </div>
         </div>
    </div>
</div>
<%
end
%>
