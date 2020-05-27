--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local modalPath = nil

local session = ngx.ctx.session
local role = session:getrole()
local usersValue = session:getusername()
local variant_helper = require("variant_helper")
local cardHelper = post_helper.getVariant(variant_helper, "CardView", "card")
local cardViewGFR = post_helper.getVariantValue(cardHelper, "cardViewGFR")

if not cardViewGFR or usersValue ~= 'assist' and cardViewGFR then
  if session:hasAccess("/modals/internet-modal.lp") then
    modalPath = "/modals/internet-modal.lp"
  end
end
  ngx.print('\
');  if post_helper.isFeatureEnabled("internetBridged", role) then   ngx.print('\
  ');  ngx.print( ui_helper.createCardHeader(T"Internet Access", modalPath) ); ngx.print('\
');  end
if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
<div class="content">\
');  else   ngx.print('\
<div class="content card_bg" data-bg-text="&#xf0ec;">\
');  end   ngx.print('\
  <p class="subinfos">\
    ');  ngx.print( T("Gateway in bridge mode") ); ngx.print('\
  </p>\
</div>\
'); 