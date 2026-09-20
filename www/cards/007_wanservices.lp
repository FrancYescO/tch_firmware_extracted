<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local attributes = {
	light = { id = "DynDNS_Status_Led" },
	span = { class = "span4",
		id = "DynDNS_Status"}
}

-- WAN services data
local wan_services_data = {
  upnp_rules = "sys.upnp.RedirectNumberOfEntries",
  firewall_rules = "uci.firewall.userredirectNumberOfEntries",
  ddns_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
  --ddns_status = "rpc.ddns.status",
}
content_helper.getExactContent(wan_services_data)

local ddns_enabled_map = {
  ["0"] = T"DynDNS disabled",
  ["1"] = T"DynDNS enabled",
  [""] = T"DynDNS disabled",
}

local ddns_light_map = {
  ["0"] = "0",
  ["1"] = "1",
}

local session = ngx.ctx.session
if session:hasAccess("/modals/wanservices-modal.lp") then
    local n_redir_rules = tonumber(wan_services_data["firewall_rules"])
    local n_upnp_rules = tonumber(wan_services_data["upnp_rules"])
%>

<div class="span3">
  <div class="smallcard">

    <%= ui_helper.createCardHeader(T"WAN Services", "modals/wanservices-modal.lp") %>

    <div class="content card_bg" data-bg-text="&#xf0c2;">
    <% ngx.print(
            ui_helper.createSimpleLight(ddns_light_map[format("%s", wan_services_data["ddns_enabled"])] or "0", ddns_enabled_map[format("%s", wan_services_data["ddns_enabled"])], attributes),
            '<p></p>',
            '<p class="subinfos">',
            format( N("<strong %s>%d port forwarding</strong> rule is defined",
                      "<strong %s>%d port forwarding</strong> rules are defined", n_redir_rules),
                      'class="modal-link" id="PortForwarding_Id" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"', n_redir_rules),
            '</p>',
            '<p class="subinfos">',
            format( N("<strong %s>%d upnp</strong> rule is active",
                      "<strong %s>%d upnp</strong> rules are active", n_upnp_rules),
                      'class="modal-link" id="upnp_Id" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"', n_upnp_rules),
            '</p>'
        )
    %>
    </div>
  </div>
</div>
<%
end
%>
