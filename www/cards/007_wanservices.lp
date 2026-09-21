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
  dmz_enable = "rpc.network.firewall.dmz.enable",
  dmz_blocked = "rpc.network.firewall.dmz.blocked",
  upnp_rules = "sys.upnp.RedirectNumberOfEntries",
  firewall_rules = "uci.firewall.userredirectNumberOfEntries",
  ddns_enabled = "uci.ddns.service.@myddns_ipv4.enabled",
  --ddns_status = "rpc.ddns.status",
}
content_helper.getExactContent(wan_services_data)

local ddns_enabled_map = {
  ["0"] = T"DynDNS Disabled",
  ["1"] = T"DynDNS Enabled",
  [""] = T"DynDNS Disabled",
}

local ddns_light_map = {
  ["0"] = "0",
  ["1"] = "1",
}



local state
local dmzstate
if wan_services_data["dmz_blocked"] == "1" then
  dmzstate = T"DMZ Blocked"
  state = "0"
else
	if wan_services_data["dmz_enable"] == "1" then
	  dmzstate = T"DMZ Enabled"
	  state = "1"
	else
	  dmzstate = T"DMZ Disabled"
	  state = "0"
  	end
end

local n_redir_rules = tonumber(wan_services_data["firewall_rules"]) or 0
local n_upnp_rules = tonumber(wan_services_data["upnp_rules"]) or 0
local modalPath = nil
local switchName = nil
local modal_link_port = 'class="modal-link" id="PortForwarding_Id" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"'
local modal_link_upnp = 'class="modal-link" id="upnp_Id" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"'
local session = ngx.ctx.session

%>

<div class="span3">
  <div class="smallcard">

    <%= ui_helper.createCardHeader(T"WAN Services", "/modals/wanservices-modal.lp", switchName, nil) %>

    <div class="content card_bg" data-bg-text="&#xf11b;">
      <div class="divtable">
    <% ngx.print(
	    ui_helper.createSimpleLight(state, dmzstate,attributes),
            ui_helper.createSimpleLight(ddns_light_map[format("%s", wan_services_data["ddns_enabled"])] or "0", ddns_enabled_map[format("%s", wan_services_data["ddns_enabled"])], attributes),
            '<div class="subinfos"><span class="simple-desc">',
            format( N(T"<strong %s>%d Port Forwarding</strong> Rule",
                      T"<strong %s>%d Port Forwarding</strong> Rules", n_redir_rules),
                      modal_link_port, n_redir_rules),
	         '</span></div>',
           '<div class="subinfos"><span class="simple-desc">',
            format( N(T"<strong %s>%d UPnP</strong> Rule",
                      T"<strong %s>%d UPnP</strong> Rules", n_upnp_rules),
                      modal_link_upnp, n_upnp_rules),
            '</span></div>'
        )
    %>
      </div>
    </div>
  </div>
</div>

