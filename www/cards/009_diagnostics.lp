<%
-- Enable localization
gettext.textdomain('webui-core')

local lfs = require("lfs")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local session = ngx.ctx.session
if session:hasAccess("/modals/diagnostics-xdsl-modal.lp") and
   session:hasAccess("/modals/diagnostics-ping-modal.lp") and
   session:hasAccess("/modals/diagnostics-connection-modal.lp") and
   session:hasAccess("/modals/diagnostics-network-modal.lp")
   then

local xdsl_exist = false
if lfs.attributes("/etc/config/xdsl", "mode") == "file" then
  xdsl_exist = true
end

%>

<div class="span3">
  <div class="smallcard">

    <%
    local eth4_data = {
      eth4_status = "sys.eth.port.@eth4.status",
    }

    if xdsl_exist == true then
      content_helper.getExactContent(eth4_data)
      if (eth4_data["eth4_status"] == "up") then
        ngx.print(ui_helper.createCardHeader(T"Diagnostics", "modals/diagnostics-ping-modal.lp"))
      else
        ngx.print(ui_helper.createCardHeader(T"Diagnostics", "modals/diagnostics-xdsl-modal.lp"))
      end
    else
      ngx.print(ui_helper.createCardHeader(T"Diagnostics", "modals/diagnostics-ping-modal.lp"))
    end
    %>
    <div class="content">
	<p class ="subinfos">
	  <strong>
             <%=T"ping and Trace Route"%><br>
          </strong>
	</p>
    </div>
  </div>
</div>
<%
end
%>

