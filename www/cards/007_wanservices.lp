--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ngx = ngx
local table = table
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local session = ngx.ctx.session
local role = session:getrole()
local dynDNSIPV6 = post_helper.isFeatureEnabled("DynDNSIPV6", role)
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "WANServices", "PortMapping")
local untaint =  string.untaint

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

local mabr_attributes = {
  light = { id = "MABR_Status_Led" },
  span = { class = "span4",
    id = "MABR_Status"}
}

-- WAN services data
local wan_services_data = { }
local mabrStatus = proxy.get("rpc.env.var.unlockedstatus") and proxy.get("rpc.env.var.unlockedstatus")[1].value
local mabrEnable
if mabrStatus then
  mabrEnable = proxy.get("rpc.X_TELECOMITALIA_IT_MABRAgent.Status") and proxy.get("rpc.X_TELECOMITALIA_IT_MABRAgent.Status")[1].value or "disabled"
  mabrEnable = mabrEnable and untaint(mabrEnable)
end

local mabr_state_map = {
  disabled = T"MABR disabled",
  running = T"MABR running",
  error = T"MABR error"
}

local status_light_map = {
  disabled = "0",
  running = "1",
  error = "0"
}

if post_helper.isFeatureEnabled("dmzOrUpnp", role) then
  wan_services_data = {
    dmz_enable = "rpc.network.firewall.dmz.enable",
    dmz_blocked = "rpc.network.firewall.dmz.blocked"
  }
else
  wan_services_data = {
    upnp_rules = "sys.upnp.RedirectNumberOfEntries",
    ddns_enabled = "uci.ddns.service.@myddns_ipv4.enabled"
  }
end
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

local ddns_light_map = {
  ["0"] = "0",
  ["1"] = "1",
}

local ddns_enabled_map = {
  ["0"] = dynDNSIPV6 and T"DynDNS IPv4 disabled" or T"DynDNS disabled",
  ["1"] = dynDNSIPV6 and T"DynDNS IPv4 enabled" or T"DynDNS enabled",
  [""] = dynDNSIPV6 and T"DynDNS IPv4 disabled" or T"DynDNS disabled"
}

local ddnsv6_enabled_map = {
  ["0"] = T"DynDNS IPv6 disabled",
  ["1"] = T"DynDNS IPv6 enabled",
  [""] = T"DynDNS IPv6 disabled"
}

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

local modalPath = nil
local modal_link_port  = ""
local modal_link_upnp = ""
if session:hasAccess("/modals/wanservices-modal.lp") then
  modalPath = "/modals/wanservices-modal.lp"
  if not post_helper.isFeatureEnabled("dmzOrUpnp", role) then
    modal_link_port = 'class="modal-link" id="PortForwarding_Id" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"'
    modal_link_upnp = 'class="modal-link" id="upnp_Id" data-toggle="modal" data-remote="modals/wanservices-modal.lp" data-id="wanservices-modal"'
  end
elseif not session:isdefaultuser() then
  return
end
  ngx.print('\
<div class="span3">\
  <div class="smallcard">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"WAN Services", modalPath, nil, nil) ); ngx.print('\
    ');  if post_helper.isFeatureEnabled("dmzOrUpnp", role) then   ngx.print('\
      <div class="content">\
      ');  if post_helper.isFeatureEnabled("wanServicesDMZAndNAT", role) or post_helper.getVariantValue(variantHelper, "DMZ", session:getrole()) then   ngx.print('\
        <p>\
          ');  ngx.print(ui_helper.createSimpleLight(state, dmzstate, dmz_attributes))  ngx.print('\
        </p>\
      ');  end   ngx.print('\
      <p>\
      ');  
        if ddns_ipv4_enabled then
          ngx.print(ui_helper.createSimpleLight(ddns_light_map[format("%s", ddns_ipv4_enabled)] or "0", ddns_enabled_map[format("%s", ddns_ipv4_enabled)], dynDns_attributes))
        end
        ngx.print('\
      </p>\
      ');  
        if dynDNSIPV6 and ddns_ipv6_enabled then
          ngx.print(ui_helper.createSimpleLight(ddns_light_map[format("%s", ddns_ipv6_enabled)] or "0", ddnsv6_enabled_map[format("%s", ddns_ipv6_enabled)], dynDns_attributes))
        end
        if mabrStatus and mabrEnable then
          ngx.print(ui_helper.createSimpleLight(status_light_map[format("%s", mabrEnable)], mabr_state_map[mabrEnable], mabr_attributes ))
        end
        ngx.print('\
      </div>\
    ');  else   ngx.print('\
      <div class="content card_bg" data-bg-text="&#xf0c2;">\
      ');  
      if session:hasAccess("/modals/dyndns-wanservices-modal.lp") then
        ngx.print(ui_helper.createSimpleLight(ddns_light_map[format("%s", wan_services_data["ddns_enabled"])] or "0", ddns_enabled_map[format("%s", wan_services_data["ddns_enabled"])], attributes))
      end
      ngx.print(
        '<p></p>',
        '<p class="subinfos">',
        format( N("<strong %s>%d port forwarding</strong> rule is defined",
          "<strong %s>%d port forwarding</strong> rules are defined", n_redir_rules),
           modal_link_port, n_redir_rules),
        '<br/>',
        format( N("<strong %s>%d UPnP</strong> rule is active",
          "<strong %s>%d UPnP</strong> rules are active", n_upnp_rules),
          modal_link_upnp, n_upnp_rules),
        '</p>'
      )
        ngx.print('\
      </div>\
    ');  end   ngx.print('\
  </div>\
</div>\
'); 