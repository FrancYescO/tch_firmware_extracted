<%
-- Enable localization
gettext.textdomain('webui-l2tp-ipsec-server')

local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local content_l2tpipsecserver = {
  state = "rpc.l2tpipsecserver.enable",
  connectedclients = "rpc.l2tpipsecserver.numberOfConnectedClients"
}

content_helper.getExactContent(content_l2tpipsecserver)

local serverenabled
local switchtext
local connectedclients = tonumber(content_l2tpipsecserver["connectedclients"]) or 0

if (content_l2tpipsecserver["state"] == '1') then
  switchtext = T"VPN server enabled"
  serverenabled = "1"
else
  switchtext = T"VPN server disabled"
  serverenabled = "0"
end

local modalPath
local session = ngx.ctx.session
if session:hasAccess("/modals/l2tp-ipsec-server-modal.lp") then
  switchName = "l2tp-ipsec-server_enabled"
  modalPath = "/modals/l2tp-ipsec-server-modal.lp"
end
%>

<div class="span3">
  <div class="smallcard">
    <%= ui_helper.createCardHeader(T"VPN Server", modalPath) %>
     <div class="content card_bg" data-bg-text="&#xf023;">
      <%
        ngx.print(
          ui_helper.createSimpleLight(serverenabled, switchtext),
          '<p class="subinfos">',
           format( N("<strong>%d client</strong> is connected",
                     "<strong>%d clients</strong> are connected", connectedclients), connectedclients),'</p>'
        )
      %>
    </div>
  </div>
</div>
