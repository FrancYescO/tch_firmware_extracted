--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local ui_helper = require("web.ui_helper")

lp.include("broadband-xdsl.lp")

local session = ngx.ctx.session
local role = session:getrole()

local allowed_encs = {
  {"llc", T"LLC"},
  {"vcmux", T"VCMUX"}
}

local wan = {
  iface = "uci.network.interface.@wan.ifname"
}
content_helper.getExactContent(wan)
local iface = wan.iface

local content, helpmsg

if iface then
  iface = iface:untaint()
  local validateNumberInRange = post_helper.getValidateNumberInRange
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
  ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.print('\
  <legend>');  ngx.print(  T"Internet VPC" ); ngx.print('</legend>\
  ');  
    local html = {}
    if content and content.adsl_vp and content.adsl_vc and content.adsl_enc then
      html[#html + 1] = ui_helper.createInputText(T"VP", "adsl_vp", content["adsl_vp"], nil, helpmsg["adsl_vp"])
      html[#html + 1] = ui_helper.createInputText(T"VC", "adsl_vc", content["adsl_vc"], nil, helpmsg["adsl_vc"])
    else
      html[#html + 1]=  ui_helper.createAlertBlock(T"Configuration of VP/VC not available")
    end
    ngx.print(html)
    ngx.print('\
</fieldset>\
'); 