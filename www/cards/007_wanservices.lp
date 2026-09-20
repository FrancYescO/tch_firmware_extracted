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

local dynDns_attributes = {
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
}
content_helper.getExactContent(wan_services_data)

local ddns_ipv4_path = "uci.ddns.service.@myddns_ipv4.enabled"
local ddns_ipv6_path = "uci.ddns.service.@myddns_ipv6.enabled"

local function get_ddns_enabled(path)
  local enabled 
  local ddns_enable_table = proxy.get(path)

  if ddns_enable_table then 
    for _, param in ipairs(ddns_enable_table) do
      enabled = param.value 
    end
  end 
  return enabled
end
    
local ddns_ipv4_enabled = get_ddns_enabled(ddns_ipv4_path)
local ddns_ipv6_enabled = get_ddns_enabled(ddns_ipv6_path)
    
local ddns_enabled = "0" 
if ddns_ipv4_enabled == "1" or ddns_ipv6_enabled == "1" then
  ddns_enabled = "1"
elseif ddns_ipv4_enabled == nil and ddns_ipv6_enabled == nil then
  ddns_enabled = nil
end

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
        if ddns_enabled then
                ngx.print(ui_helper.createSimpleLight(ddns_light_map[format("%s", ddns_enabled)] or "0", ddns_enabled_map[format("%s", ddns_enabled)], dynDns_attributes))
        end
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