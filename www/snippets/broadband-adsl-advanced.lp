--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local tim_helper
local wanIntf = post_helper.getActiveInterface()
local untaint = string.untaint
local xtmPath = "uci.xtm.atmdevice.@."

lp.include("broadband-xdsl.lp")

local session = ngx.ctx.session
local role = session:getrole()

if post_helper.isFeatureEnabled("broadBandModalTI", role) then
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
  if post_helper.isFeatureEnabled("broadBandModalTI", role) then
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
if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" and not next(helpmsg) then
  local wan_intf =  proxy.get("uci.network.interface.@wan.ifname")
  wan_intf = wan_intf and wan_intf[1] and wan_intf[1].value
  local del_path = wan_intf and "uci.xtm.atmdevice.@".. wan_intf.."."
  local atm_content_get = wan_intf and proxy.get(del_path)
  local succ,err = wan_intf and proxy.del(untaint(del_path))
  local atm_content = {}
  for i,v in ipairs(atm_content_get) do
     atm_content[v.param] = v.value
  end
  local args = ngx.req.get_post_args()
  local paramMapForNAT = {
          vpi = "vpi",
          vci = "vci",
          path = "path",
          ulp = "ulp",
          td = "td",
          priority = "priority",
          enc = "enc",
          weight = "weight"
        }
  atm_content["vci"] = args.adsl_vc and untaint(args.adsl_vc)
  atm_content["vpi"] = args.adsl_vp and untaint(args.adsl_vp)
  if atm_content["vci"] and atm_content["vpi"] then
    content_helper.addNewObject(xtmPath, atm_content, paramMapForNAT, nil, "atm_"..atm_content.vpi.."_"..atm_content.vci)
    proxy.set("uci.network.interface.@wan.ifname", "atm_"..atm_content.vpi.."_"..atm_content.vci)
    proxy.apply()
  end
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
