<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session

local content = {
    mode = "rpc.network.firewall.mode",
    numrules = "rpc.network.firewall.UserRuleNumberOfEntries",
    numrules_v6 = "rpc.network.firewall.UserRuleV6NumberOfEntries",
}

content_helper.getExactContent(content)

local modes = setmetatable({
    lax = T"Lax",
    normal = T"Normal",
    high = T"High",
    user = T"User"
    }, untaint_mt)

%>
<div class="span3">
  <div class="smallcard">
    <%= ui_helper.createCardHeader(T"Firewall", "modals/firewall-modal.lp") %>
    <div class="content card_bg" data-bg-text="&#xf074;">
      <div class="divtable">
      <p class="subinfos">
       <%
            local html = {}
            html[#html+1] = format(T"Firewall Level: <strong>%s</strong><br>", modes[content.mode] or "")
            if content.mode == "user" then
                html[#html+1] = "<p class='subinfos'>"     
                html[#html+1] = format( N(T"<strong>%d</strong> IPv4 Rule Defined",T"<strong>%d</strong> IPv4 Rules Defined", tonumber(content.numrules)), content.numrules)
                html[#html+1] = "</p><p class='subinfos'>"
                html[#html+1] = format( N(T"<strong>%d</strong> IPv6 Rule Defined",T"<strong>%d</strong> IPv6 Rules Defined", tonumber(content.numrules_v6)), content.numrules_v6)
                html[#html+1] = "</p>"
            end
            ngx.print(html)
        %>
      </p>
      </div>
    </div>
  </div>
</div>

