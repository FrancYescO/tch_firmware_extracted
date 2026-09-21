<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local session = ngx.ctx.session
local modalPath = "/modals/helper-modal.lp"



local debug = 0
local args = ngx.req.get_uri_args()
if args then
  for key, val in pairs(args) do
    if key=="debug"  then debug = 1  end
  end
end

if not session:isdefaultuser() and debug == 1 then
  local modal_link = format("class=\"modal-link\" data-toggle=\"modal\" data-remote=\"%s\" data-id=\"helper-modal\"",modalPath)
  local helper_uci_path = "uci.firewall.helper."
  local helper_uci_content = content_helper.getMatchedContent (helper_uci_path)
  local enabled_count = 0
  local disabled_count = 0 
  for _, v in pairs (helper_uci_content) do
     if v["enable"] == "0" then
        disabled_count = disabled_count + 1
     else
        enabled_count = enabled_count + 1
     end
  end
  
  %>
  
  <div class="span3">
      <div class="smallcard">
          <%= ui_helper.createCardHeader(T"NAT Helpers", modalPath) %>
          <div class="content card_bg" data-bg-text="&#xf0ad;">
          <div class="divtable">
              <%if enabled_count ~= 0 then%>
                <p class="subinfos">
                <%
                ngx.print(format( N('<strong %1$s>%2$d Enabled Helper</strong>', 
                                    '<strong %1$s>%2$d Enabled Helpers</strong>', enabled_count), 
                                    modal_link, enabled_count))
                %>
                </p>
                <%
              end
              if disabled_count ~= 0 then%>
                <p class="subinfos">
                <%
                ngx.print(format( N('<strong %1$s>%2$d Disabled Helper</strong>', 
                                    '<strong %1$s>%2$d Disabled Helpers</strong>', disabled_count), 
                                    modal_link, disabled_count))
                %>
                </p>
              <%end%>
           </div>
           </div>
      </div>
  </div>
<%
end
%>
