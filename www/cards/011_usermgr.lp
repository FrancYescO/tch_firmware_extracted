<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session

if session:hasAccess("/modals/usermgr-modal.lp") then
%>

<div class="span3">
    <div class="smallcard">
        <%= ui_helper.createCardHeader(T"Management", "modals/usermgr-modal.lp") %>
        <div class="content">
            <p class="subinfos">
		<strong>
		   <%=T"User management and log viewer"%><br>		      
		</strong>
            </p>
        </div>
    </div>
</div>

<%
end
%>
