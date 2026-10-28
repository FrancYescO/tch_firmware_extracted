--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local tim_helper
local wanIntf = post_helper.getActiveInterface()

lp.include("broadband-xdsl.lp")

local session = ngx.ctx.session
local role = session:getrole()

if post_helper.isFeatureEnabled("broadBandWanLanPort", role) then
  tim_helper = require("tim_helper")
end


local allowed_encs = {
  {"llc", T"LLC"},
  {"vcmux", T"VCMUX"}
}

local wan = {
  iface = string.format("uci.network.interface.@%s.ifname", wanIntf)
}
content_helper.getExactContent(wan)
local iface = wan.iface

local content, helpmsg

if iface then
  iface = iface:untaint()
  local validateNumberInRange
  if post_helper.isFeatureEnabled("broadBandWanLanPort", role) then
    validateNumberInRange = tim_helper.getValidateNumberInRange
  else
    validateNumberInRange = post_helper.getValidateNumberInRange
  end
  local validateInEnumSelect = post_helper.getValidateInEnumSelect
  local mapValid = {
    adsl_vp = validateNumberInRange(0, 255),
    adsl_vc = validateNumberInRange(0, 65535),
    adsl_enc = validateInEnumSelect(allowed_encs)
  }

  local mapParams = {
    adsl_vp = "uci.xtm.atmdevice.@" .. iface .. ".vpi",
    adsl_vc = "uci.xtm.atmdevice.@" .. iface .. ".vci",
    adsl_enc = "uci.xtm.atmdevice.@" .. iface .. ".enc"
  }
  content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
end
  ngx.print('\
\
<fieldset>\
  <legend>');  ngx.print( T"Internet VPC" ); ngx.print('</legend>\
  ');  
    local html = {}
    if post_helper.isFeatureEnabled("broadBandInternetChannel", role) then
      if content and content.adsl_vp and content.adsl_vc and content.adsl_enc then
        html[#html + 1] = ui_helper.createInputText(T"VP", "adsl_vp", content["adsl_vp"], nil, helpmsg["adsl_vp"])
        html[#html + 1] = ui_helper.createInputText(T"VC", "adsl_vc", content["adsl_vc"], nil, helpmsg["adsl_vc"])
        if role == "ispuser" then
          html[#html + 1] = ui_helper.createInputSelect(T"Encapsulation", "adsl_enc", allowed_encs, content["adsl_enc"])
        end
      else
        html[#html + 1]=  ui_helper.createAlertBlock(T"Configuration of VP/VC not available")
      end
    else
      if content and content.adsl_vp and content.adsl_vc then
        html[#html + 1] = ui_helper.createLabel(T"VP", content["adsl_vp"])
	html[#html + 1] = ui_helper.createLabel(T"VC", content["adsl_vc"])
      else
	html[#html + 1] = ui_helper.createAlertBlock(T"VP/VC is not configured")
      end
    end
    ngx.print(html)
    ngx.print('\
</fieldset>\
'); 