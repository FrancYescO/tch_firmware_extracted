--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")
local variant_helper = require("variant_helper")
local format = string.format
local wanIntf = post_helper.getActiveInterface()

-- Non-configurable data
local cs = {}
if post_helper.isFeatureEnabled("internetmodeHelper", role) then
  cs = {
    uci_wan_auto = format("uci.network.interface.@%s.auto", wanIntf),
    ipaddr = format("rpc.network.interface.@%s.ipaddr", wanIntf)
  }
else
  local interface_name = session:retrieve("network_interface_name") or wanIntf
  cs = {
    uci_wan_auto = format("uci.network.interface.@%s.auto",interface_name),
    ipaddr = format("rpc.network.interface.@%s.ipaddr",interface_name),
  }
end
content_helper.getExactContent(cs)

-- Figure out interface state
local static_state = "disabled"
local static_state_map = {
    disabled = T"Static disabled",
    connected = T"Static on",
}

local static_light_map = {
  disabled = "off",
  connected = "green",
}

if cs["uci_wan_auto"] ~= "0" and cs["ipaddr"]:len() > 0 then
    cs["uci_wan_auto"] = "1"
    static_state = "connected"
end

local modalPath = nil

local session = ngx.ctx.session
local usersValue = session:getusername()
local cardHelper = post_helper.getVariant(variant_helper, "CardView", "card")
local cardViewGFR = post_helper.getVariantValue(cardHelper, "cardViewGFR")

if not cardViewGFR or usersValue ~= 'assist' and cardViewGFR then
  if session:hasAccess("/modals/internet-modal.lp") then
    modalPath = "/modals/internet-modal.lp"
  end
end

  ngx.print('\
');  if post_helper.isFeatureEnabled("internetmodeHelper", role) then   ngx.print('\
  ');  ngx.print( ui_helper.createCardHeader(T"Internet Access", modalPath, nil, nil) ); ngx.print('\
');  end
if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
  <div class="content">\
');  else   ngx.print('\
  <div class="content card_bg" data-bg-text="&#xf0ec;">\
');  end   ngx.print('\
  ');  ngx.print( ui_helper.createSimpleLight(nil, static_state_map[static_state], { light = { class = static_light_map[static_state] } }) ); ngx.print('\
  <p class="subinfos">\
     ');  if static_state == "connected" then
            ngx.print(format(T'WAN IP is <strong>%s</strong>', cs["ipaddr"]))
        end
       ngx.print('\
  </p>\
</div>\
'); 