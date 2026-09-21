<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local session = ngx.ctx.session
local modalPath = "/modals/xdsl-low-modal.lp"



local debug = 0
local args = ngx.req.get_uri_args()
if args then
  for key, val in pairs(args) do
    if key=="debug"  then debug = 1  end
  end
end

if not session:isdefaultuser() and debug == 1 then
  local content = {
      dsl0_enabled               = "uci.xdsl.xdsl.@dsl0.enabled",
      dsldiag                    = "sys.dsldiag.Enable",
  }
  content_helper.getExactContent(content)
  
  local xDSL_State = "Disabled"
  if content.dsl0_enabled == "1" then
     xDSL_State = "Enabled"
  end
  
  local xDSLDiag_State = "Disabled"
  if content.dsldiag == "1" then
     xDSLDiag_State = "Enabled"
  end
  
  local state_map_DSL = {
      Disabled = T"xDSL Disabled",
      Enabled = T"xDSL Enabled",
  }
  
  local state_map_DSLdiag = {
      Disabled = T"DSLDiag Disabled",
      Enabled = T"DSLDiag Enabled",
  }
  
  local light_map = {
    Disabled = "off",
    Enabled = "green",
  }
  %>
  
  <div class="span3">
      <div class="smallcard">
          <%= ui_helper.createCardHeader(T"xDSL Config", modalPath) %>
          <div class="content card_bg" data-bg-text="&#xf0ad;">
          <div class="divtable">
                <%
                html={}
                html[#html+1] = ui_helper.createSimpleLight(nil, state_map_DSL[xDSL_State], { light = { class = light_map[xDSL_State] } })
                if content.dsldiag == "1" then
                     html[#html+1] = [[<br/>]]
                     html[#html+1] = ui_helper.createSimpleLight(nil, state_map_DSLdiag[xDSLDiag_State], { light = { class = light_map[xDSLDiag_State] } })
                end
                ngx.print(html)
                %>
           </div>
           </div>
      </div>
  </div>
<%
end
%>

