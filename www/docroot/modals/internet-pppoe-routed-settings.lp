--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local session = ngx.ctx.session
local role = session:getrole()
local imh = require("internetmode_helper").get()
local checkgpon = require("checkgponboard_helper")
local is_gpon = checkgpon.isGPONBoard()
local tabdata = dyntab_helper.process(imh)
local content_helper = require("web.content_helper")
local mode_current = tabdata.current.name
local mode_options = tabdata.options
local content, helpmsg
local wanIntf = post_helper.getActiveInterface()


local wan_ppp_ll_intf = proxy.get("rpc.network.interface.@"..wanIntf..".ppp.ll_intf")[1].value
local wan_ppp_over_atm = proxy.get(string.format("uci.xtm.atmdevice.@%s.", wan_ppp_ll_intf)) ~= nil
if not wan_ppp_over_atm then
  for modes, modesValue in ipairs(mode_options) do
    if modesValue[1] == "pppoa" then
      table.remove(mode_options, modes)
      break
    end
  end
end

-- For Available Interfaces
-- var val_selected is to store the wan intf name dynamically changed by user from the drop down list
local val_selected = ""

-- Fetching available wan interfaces
local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.",firewall_zone)
local allWan_intfs = {}
for _, v in ipairs(firewall_zone_path) do
  if (v["wan"] == "1" and v["name"] ~= "mgmt") then
    allWan_intfs[#allWan_intfs + 1] = {v["name"], v["name"]}
  end
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SELECT" then
  val_selected = ngx.req.get_post_args().interface
  ngx.ctx.session:store("postedIntf_internet_modal", val_selected)
end

-- If other interfaces in drop down then show the selected interface else show the wan interface in default case
val_selected = session:retrieve("postedIntf_internet_modal") or wanIntf

local mapParams, mapValid
-- Auto WAN Sensing
if post_helper.isFeatureEnabled("autoWANSensingInternetAcces" , role) then
  local content_params = {
    variant = "uci.env.var.iinet_variant"
  }
  content_helper.getExactContent(content_params)

  mapParams = {
    wans_enable = "uci.wansensing.global.enable",
    wans_l2type = "uci.wansensing.global.l2type",
    wans_l3type = "uci.wansensing.global.l3type",
    ipoe_auto = "uci.network.interface.@ipoe.auto",
    ppp_auto = "uci.network.interface.@ppp.auto",
    pppv_auto = "uci.network.interface.@pppv.auto",
    ipoe_ifname = "uci.network.interface.@ipoe.ifname",
    ppp_ifname = "uci.network.interface.@ppp.ifname",
    pppv_ifname = "uci.network.interface.@pppv.ifname",
    atm_ulp = "uci.xtm.atmdevice.@atm_ppp.ulp",
    atm_enc = "uci.xtm.atmdevice.@atm_ppp.enc"
  }

  if content_params.variant == "novus" then
    mapParams.pppv_auto = nil
    mapParams.pppv_ifname = nil
  end

  local gVIES = post_helper.getValidateInEnumSelect
  local vB = post_helper.validateBoolean
  local function validateWansEnabled(value, object, key)
    local success, msg = vB(value)
    if not success then
      return success, msg
    end
    if value == "1" then
      object["wans_l2type"] = nil
      object["wans_l3type"] = nil
      object["ipoe_auto"] = nil
      object["ppp_auto"] = nil
      object["pppv_auto"] = nil
      object["ipoe_ifname"] = nil
      object["ppp_ifname"] = nil
      object["pppv_ifname"] = nil
      object["atm_ulp"] = "eth"
      object["atm_enc"] = "llc"
    else
      object["wans_l2type"] = ""
      object["wans_l3type"] = ""
      object["ipoe_auto"] = "0"
      object["ppp_auto"] = "0"
      object["pppv_auto"] = "0"
      object["ipoe_ifname"] = ""
      object["ppp_ifname"] = ""
      object["pppv_ifname"] = ""
      object["atm_ulp"] = nil
      object["atm_enc"] = nil
    end
    return true
  end

  local function alwaysTrue()
    return true
  end

  mapValid = {
    wans_enable = validateWansEnabled,
    wans_l2type = alwaysTrue,
    wans_l3type = alwaysTrue,
    ipoe_auto = alwaysTrue,
    ppp_auto = alwaysTrue,
    pppv_auto = alwaysTrue,
    ipoe_ifname = alwaysTrue,
    ppp_ifname = alwaysTrue,
    pppv_ifname = alwaysTrue,
    atm_ulp = alwaysTrue,
    atm_enc = alwaysTrue
  }

  content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
end
  ngx.print('\
\
');  
  if not tabdata.current.ajax then
  -- only display if not doing an ajax request
  ngx.print('\
');  
-- Currently, the only advanced field is the conncection mode.
-- So if it's not included, there's no need for an advanced button.
ngx.print(ui_helper.createHeader(T"Internet Access", #imh > 1, true))
  ngx.print('\
<div class = "modal-body update">\
');  
  if is_gpon then
    local html = {}
    local tabs = {
      {
        desc = T"PPP Connection",
        active = "active",
	target = "modals/internet-modal.lp"
      },
      {
        desc = T"DHCP Connection",
	target = "modals/internet-wan2-modal.lp"
      },
    }
    html[#html+1] = ui_helper.createModalTabs(tabs)
    ngx.print(html)
  end
  ngx.print('\
');  
  local tabsConf = {
    {
      desc = T"IPv4 Configuration",
      active = "active",
      target = "modals/internet-modal.lp"
    },
    {
      desc = T"IPv6 Configuration",
      target = "modals/internet-ex-modal.lp"
    },
  }
  ngx.print(ui_helper.createModalTabs(tabsConf))
  ngx.print('\
<form id="interface-form" class = "form-horizontal" method = "post" action = "modals/internet-pppoe-routed-settings.lp">\
');  
if session:hasAccess("/modals/internet-"..mode_current.."-routed-configuration.lp") then
  local tab = {
    {
      desc = T"Status",
      target = "modals/internet-"..mode_current.."-routed-status.lp"
    },
    {
      desc = T"Configuration",
      target = "modals/internet-"..mode_current.."-routed-configuration.lp"
    }
  }
  if post_helper.isFeatureEnabled("InternetStatusSettingsTab" , role) then
    tab[#tab+1] = {
      desc = T"Settings",
      active = "active",
      target = "modals/internet-"..mode_current.."-routed-settings.lp"
    }
  end
  ngx.print(ui_helper.createModalTabs(tab))
end
  ngx.print('\
\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
');  
  if #imh > 1 then
  -- Only included if there are 2 or more connection modes
  ngx.print('\
<fieldset id = "conn_mode">\
<legend>');  ngx.print( T"Connection mode" ); ngx.print('</legend>\
\
');  
  local html = {}

  local mode_attributes = {
    radio = {
      class = "inline"
    },
    input = {
      class = "no-save",
      ["data-for"] = "SWITCH_MODE"
    }
  }
  local mode_button = {
    button = {
      ["data-name"] = "action",
      ["data-value"] = "SWITCH_MODE"
    }
  }

  if not post_helper.isFeatureEnabled("autoWANSensingInternetAcces" , role) then
    html[#html+1] = ui_helper.createInputRadio(T"Mode", "newmode", mode_options, mode_current, mode_attributes)
    html[#html+1] = ui_helper.createButton("", T"Switch connection mode", "icon-cog", mode_button)
  else
    ngx.print(ui_helper.createSwitch(T"Auto WAN sensing","wans_enable",content["wans_enable"]))
    if(content["wans_enable"] == '0') then
      html[#html+1] = ui_helper.createInputRadio(T"Mode", "newmode", mode_options, mode_current, mode_attributes)
      html[#html+1] = ui_helper.createButton("", "Switch connection mode", "icon-cog", mode_button)
    else
      html[#html+1] = ui_helper.createLabel(T"Mode",tabdata.current.description)
    end
  end
  html[#html+1] = ui_helper.createInputSelect(T"Available Interfaces", "interface", allWan_intfs, val_selected, {select={class="monitor-changes"}})
  ngx.print(html)
  ngx.print('\
</fieldset>\
');  end   ngx.print('\
');  end   ngx.print('\
');  
  if ngx.req.get_method() == "POST"  and ngx.req.get_post_args().action == "SWITCH_MODE" then
    local postargs = ngx.req.get_post_args()
    if postargs.newmode ~= "static" then
      proxy.del("uci.network.interface.@"..wanIntf..".dns.")
      proxy.get("uci.network.interface.@"..wanIntf..".dns.")
      if postargs.newmode == "pppoe" then
        proxy.set("uci.xtm.atmdevice.@atmwan.enc", "llc")
      elseif postargs.newmode == "pppoa" then
        proxy.set("uci.xtm.atmdevice.@atmwan.enc", "vcmux")
      end
      proxy.apply()
    end
  end
  ngx.print('\
\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
<script>\
 var getCSRFtoken = "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('";\
</script>\
<script src="/js/internet-routed-settings.js"></script>\
'); 