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
  dmz_enable = "uci.firewall.redirectsgroup.@dmzredirects.enabled",
  upnp_rules = "sys.upnp.RedirectNumberOfEntries",
  firewall_rules = "uci.firewall.userredirectNumberOfEntries",
  ddns_enabled = "uci.ddns.service.@myddns.enabled",
  ddns_status = "rpc.ddns.status",
}
content_helper.getExactContent(wan_services_data)

local ddns_state_map = {
  disabled = T"DynDNS Disabled",
  connecting = T"DynDNS Connecting",
  connected = T"DynDNS Connected",
  error = T"DynDNS Error"
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

local state

    local dmzstate
    if wan_services_data["dmz_enable"] == "1" then
      dmzstate = T"DMZ Enabled"
      state = "1"
    else
      dmzstate = T"DMZ Disabled"
      state = "0"
    end
    local tag_info_NSUB = 'class="modal-link" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"'
    local tag_info_SUB = 'class="modal-link alert-danger" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"'
    local tag_info_PF = tag_info_NSUB
    local tag_info_UPNP = tag_info_NSUB
    local n_redir_rules = tonumber(wan_services_data["firewall_rules"])
    if n_redir_rules >0 and subnetexists == 1 then 
      tag_info_PF = tag_info_SUB
    end 
    local n_upnp_rules = tonumber(wan_services_data["upnp_rules"])
    if n_upnp_rules >0 and subnetexists == 1 then 
      tag_info_UPNP = tag_info_SUB
    end 
%>

<div class="span3">
  <div class="smallcard">

    <%= ui_helper.createCardHeader(T"WAN Services", "modals/wanservices-modal.lp") %>

    <div class="content card_bg" data-bg-text="&#xf11b;">
      <div class="divtable">
    <% ngx.print(
	    ui_helper.createSimpleLight(state, dmzstate,attributes),
       	    ui_helper.createSimpleLight(ddns_light_map[ddns_status], ddns_state_map[ddns_status], attributes),
            '<div class="subinfos"><span class="simple-desc">',
            format( N(T"<strong %s>%d Port Forwarding</strong> Rule",
                      T"<strong %s>%d Port Forwarding</strong> Rules", n_redir_rules),
                      tag_info_PF, n_redir_rules),
	         '</span></div>',
           '<div class="subinfos"><span class="simple-desc">',
            format( N(T"<strong %s>%d UPnP</strong> Rule",
                      T"<strong %s>%d UPnP</strong> Rules", n_upnp_rules),
                      tag_info_UPNP, n_upnp_rules),
            '</span></div>'
        )
    %>
      </div>
    </div>
  </div>
</div>

