--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ngx = ngx
local proxy = require("datamodel")
local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local attributes = { span = { class = "span4" } }

-- WAN services data
local wan_services_data = {
  dmz_enable = "rpc.network.firewall.dmz.enable",
  dmz_blocked = "rpc.network.firewall.dmz.blocked",
  upnp_rules = "sys.upnp.RedirectNumberOfEntries",
  firewall_rules = "uci.firewall.userredirectNumberOfEntries",
}
content_helper.getExactContent(wan_services_data)

local session = ngx.ctx.session
if session:hasAccess("/modals/wanservices-modal.lp") then
    local state
    local dmzstate
    if wan_services_data["dmz_blocked"] == "1" then
        dmzstate = T"DMZ blocked"
        state = "0"
    else
      if wan_services_data["dmz_enable"] == "1" then
        dmzstate = T"DMZ enabled"
        state = "1"
      else
        dmzstate = T"DMZ disabled"
        state = "0"
      end
    end

    local n_redir_rules = tonumber(wan_services_data["firewall_rules"])
    local n_upnp_rules = tonumber(wan_services_data["upnp_rules"])
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
\
    ');  ngx.print( ui_helper.createCardHeaderNoIcon(T"WAN Services", "modals/wanservices-modal.lp") ); ngx.print('\
\
    <div class="content">\
    ');  
        ngx.print(ui_helper.createSimpleLight(state, dmzstate))
        ngx.print('<p></p>',
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
      ngx.print('\
    </div>\
  </div>\
</div>\
');  
end
  ngx.print('\
'); 