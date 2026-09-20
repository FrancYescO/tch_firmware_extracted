--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ngx = ngx
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local dynDns_attributes = {
	light = { id = "DynDNS_Status_Led" },
	span = { class = "span4",
	id = "DynDNS_Status"}
}

local dmz_attributes = {
	light = { id = "DMZ_Status_Led" },
	span = { class = "span4",
	id = "DMZ_Status"}
}

-- WAN services data
local wan_services_data = {
  dmz_enable = "rpc.network.firewall.dmz.enable",
  dmz_blocked = "rpc.network.firewall.dmz.blocked",
  upnp_rules = "sys.upnp.RedirectNumberOfEntries",
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

local pf_path = proxy.get("rpc.network.firewall.portforward.")
local pf_data = content_helper.convertResultToObject("rpc.network.firewall.portforward.",pf_path)
local pf_rule_len = {}
for _,v in ipairs(pf_data) do
  if v.src == "wan" and v.dest == "lan" then
    pf_rule_len[#pf_rule_len+1] = 1
  end
end

local n_redir_rules = #pf_rule_len
local n_upnp_rules = tonumber(wan_services_data["upnp_rules"])
local modalPath = "modals/wanservices-modal.lp"
local switchName = nil
local modal_link_port = 'class="modal-link" id="PortForwarding_Id" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"'
local modal_link_upnp = 'class="modal-link" id="upnp_Id" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"'

ngx.print('\
\
<div class="span3">\
  <div class="smallcard">',
    ui_helper.createCardHeader(T"WAN Services", modalPath, switchName, nil), '\
\
    <div class="content card_bg" data-bg-text="&#xf11b;">\
      <div class="divtable">',
	    ui_helper.createSimpleLight(state, dmzstate, dmz_attributes),
            ui_helper.createSimpleLight(ddns_light_map[format("%s", wan_services_data["ddns_enabled"])] or "0", ddns_enabled_map[format("%s", wan_services_data["ddns_enabled"])], dynDns_attributes),
            '<div class="subinfos"><span class="simple-desc">',
            format( N(T"<strong %s>%d Port Forwarding</strong> Rule",
                      T"<strong %s>%d Port Forwarding</strong> Rules", n_redir_rules),
                      modal_link_port, n_redir_rules),
	         '</span></div>',
           '<div class="subinfos"><span class="simple-desc">',
            format( N(T"<strong %s>%d UPnP</strong> Rule",
                      T"<strong %s>%d UPnP</strong> Rules", n_upnp_rules),
                      modal_link_upnp, n_upnp_rules),
            '</span></div>\
      </div>\
    </div>\
  </div>\
</div>');

