--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local dyntab_helper = require("web.dyntab_helper")
local session = ngx.ctx.session
local role = session:getrole()
local imh = require("internetmode_helper").get()
local tabdata = dyntab_helper.process(imh)
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local usersValue = session:getusername()
local cardHelper = post_helper.getVariant(variant_helper, "CardView", "card")
local cardViewGFR = post_helper.getVariantValue(cardHelper, "cardViewGFR")

if post_helper.isFeatureEnabled("internetmodeHelper", role) then
  if not session:hasAccess("/modals/internet-modal.lp") and not session:isdefaultuser() then
    return
  end
    ngx.print('\
\
  <div class="span3">\
    <div class="smallcard">\
\
  ');  
    lp.setpath("/www/cards/snippets/")
    lp.include(tabdata.current.card)
    -- have to bring it back to original value ... singleton
    lp.setpath("/www/cards/")
    ngx.print('\
    </div>\
  </div>\
');  else
  session:store("network_interface_name", "wan")
  -- Display the card but do not give access if not allowed
  local switchName = nil
  local modalPath = nil

  if not cardViewGFR or cardViewGFR and usersValue ~= "assist" then
    if session:hasAccess("/modals/internet-modal.lp") then
      switchName = "uci_wan_auto"
      modalPath = "/modals/internet-modal.lp"
    end
  end

  local content_params = {
    variant = "uci.env.var.iinet_variant",
  }
  content_helper.getExactContent(content_params)
    ngx.print('\
\
  <div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Internet", modalPath) ); ngx.print('\
    ');  if post_helper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
    <div class="content">\
    ');  else   ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf0ec;">\
    ');  end   ngx.print('\
      <div class="divtable">\
      ');  
        lp.setpath("/www/cards/snippets/")
        if content_params.variant ~= "novus" then
          lp.include("003_internet_wan_sensing.lp")
        end
        lp.include("003_internet_pvc_vlan.lp")
        lp.include(tabdata.current.card)
        lp.setpath("/www/cards/")
        ngx.print('\
      </div>\
    </div>\
  </div>\
  </div>\
');  end   ngx.print('\
'); 