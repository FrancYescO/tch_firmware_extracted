<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local attributes = { span = { class = "span4" } }

-- WAN services data
local wan_services_data = {
  upnp_rules = "sys.upnp.RedirectNumberOfEntries",
  firewall_rules = "uci.firewall.userredirectNumberOfEntries",
  ddns_enabled = "uci.ddns.service.@myddns.enabled",
  ddns_status = "rpc.ddns.status",
}
content_helper.getExactContent(wan_services_data)

local ddns_state_map = {
  disabled = T"DynDNS disabled",
  connecting = T"DynDNS connecting",
  connected = T"DynDNS connected",
  error = T"DynDNS error"
}

local ddns_light_map = {
  disabled = "0",
  connected = "1",
  connecting = "2",
  error = "4"
}

local ddns_status
if wan_services_data.ddns_enabled == "0" then
  ddns_status = "disabled"
else
  if wan_services_data.ddns_status then
    ddns_status = format("%s", wan_services_data.ddns_status)
    if not ddns_state_map[ddns_status] then
        ddns_status = "error"
    end
  else
    ddns_status = "connecting"
  end
end

local session = ngx.ctx.session
if session:hasAccess("/modals/wanservices-modal.lp") then
    local n_redir_rules = tonumber(wan_services_data["firewall_rules"])
    local n_upnp_rules = tonumber(wan_services_data["upnp_rules"])
%>

<div class="span3">
  <div class="smallcard">

    <%= ui_helper.createCardHeader(T"WAN Services", "modals/wanservices-modal.lp") %>

    <div class="content">
    <% ngx.print(
	    ui_helper.createSimpleLight(ddns_light_map[ddns_status], ddns_state_map[ddns_status], attributes),
            '<p></p>',
            '<p class="subinfos">',
            format( N("<strong %s>%d port forwarding</strong> rule is defined",
                      "<strong %s>%d port forwarding</strong> rules are defined", n_redir_rules),
                      'class="modal-link" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"', n_redir_rules),
            '</p>',
            '<p class="subinfos">',
            format( N("<strong %s>%d upnp</strong> rule is active",
                      "<strong %s>%d upnp</strong> rules are active", n_upnp_rules),
                      'class="modal-link" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"', n_upnp_rules),
            '</p>'
        )
    %>
    </div>
  </div>
</div>
<%
end
%>
