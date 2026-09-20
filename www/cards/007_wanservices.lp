<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

-- WAN services data
local wan_services_data = {
  dmz_enable = "uci.firewall.redirectsgroup.@dmzredirects.enabled",
  upnp_rules = "sys.upnp.RedirectNumberOfEntries",
  firewall_rules = "uci.firewall.userredirectNumberOfEntries"
}
content_helper.getExactContent(wan_services_data)

local session = ngx.ctx.session
if session:hasAccess("/modals/wanservices-modal.lp") then
    local dmzstate
    if wan_services_data["dmz_enable"] == "1" then
      dmzstate = T"DMZ enabled"
    else
      dmzstate = T"DMZ disabled"
    end

    local n_redir_rules = tonumber(wan_services_data["firewall_rules"])
    local n_upnp_rules = tonumber(wan_services_data["upnp_rules"])
%>

<div class="span3">
  <div class="smallcard">

    <%= ui_helper.createCardHeaderNoIcon(T"WAN Services", "modals/wanservices-modal.lp") %>

    <div class="content">
    <% ngx.print(
            ui_helper.createSimpleLight(wan_services_data["dmz_enable"], dmzstate),
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
