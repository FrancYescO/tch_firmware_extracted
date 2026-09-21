<%
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")

local find, sub, format = string.find, string.sub, string.format
local version = proxy.get("uci.version.version.@version[0].marketing_version")
if version then
    version = version[1].value
else
    version = ""
end
local name = proxy.get("uci.version.version.@version[0].marketing_name")
if name then
    name = name[1].value
else
    name = ""
end
local CPEname = format("%s", proxy.get("uci.env.var.prod_friendly_name")[1].value)

local session = ngx.ctx.session
if session:hasAccess("/modals/gateway-modal.lp") then

local headerAttr = {
    icon = {
        class = "icon-info-sign"
    }
}

%>
<div class="span3">
  <div class="smallcard">
    <%= ui_helper.createCardHeader(T"Gateway", "modals/gateway-modal.lp", nil, nil, headerAttr) %>
    <div class="content card_bg" data-bg-text="&#xf129;">
      <div class="divtable">
        <div class="light green"></div>
        <p><%= T"Version" %> <%= name .. " (" .. version .. ")" %></p>
        <div data-toggle="modal" data-remote="modals/gateway-modal.lp" data-id="gateway-modal">
         <%
         if session:hasAccess("/modals/setup-modal.lp") then
            local set_link='class="modal-link hand" data-toggle="modal" data-remote="modals/setup-modal.lp" data-id="setup-modal"'
            local cog='<i class="icon-cog"></i>'
            ngx.print(format('<p class="subinfos"><strong %s>%s  %s</strong></p> ', set_link,cog,T"Setup Your Gateway"))
         else
         %>
          <img class="someInfos" href="#" rel="tooltip" data-placement="top" data-original-title="<%= CPEname %>" src="/img/gateway.png" alt="gateway">
         <%
         end
         %>
        </div>
      </div>
    </div>
  </div>
</div>
<%
end
%>
