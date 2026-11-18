--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local match, format, find = string.match, string.format, string.find
local session = ngx.ctx.session
local role = session:getrole()
local dyntab_helper = require("web.dyntab_helper")
local imh = require("internetmode_helper").get()
local tabdata = dyntab_helper.process(imh)
local mode_current = tabdata.current.name
local wanIntf = post_helper.getActiveInterface()


local mapParams = {
  uci_wan_auto = format("uci.network.interface.@%s.auto", wanIntf)
}

-- Shortcuts to validation helpers to make lines shorter
local validateConditional = post_helper.getConditionalValidation
local validateBoolean = post_helper.validateBoolean
local validateNonEmpty = post_helper.validateNonEmptyString
local validatePassword = post_helper.getValidationPassword
local validateOptional = post_helper.getOptionalValidation

local function isWanEnabled(value, object, key)
  return object["uci_wan_auto"] ~= "0"
end

-- Validation allows empty values if wan access disabled but will stil check for validity if the parameter is set
-- if wan is enabled then it checks for validaty anyway
local mapValid = {
  uci_wan_auto = validateBoolean
}

local content = post_helper.handleQuery(mapParams, mapValid)

local content_rpc = {
  wan_ppp_state = format("rpc.network.interface.@%s.ppp.state", wanIntf),
  wan_ppp_error = format("rpc.network.interface.@%s.ppp.error", wanIntf),
}

content_helper.getExactContent(content_rpc)

local ppp_state_map = {
  disabled = T"disabled",
  disconnecting = T"disconnecting",
  connected = T"connected",
  connecting = T"connecting",
  disconnected = T"disconnected",
  error = T"error",
  AUTH_TOPEER_FAILED = T"authentication failed",
  NEGOTIATION_FAILED =  T"negotiation failed"
}

local untaint_mt = require("web.taint").untaint_mt
setmetatable(ppp_state_map, untaint_mt)

local ppp_light_map = {
  disabled = "off",
  disconnected = "red",
  disconnecting = "orange",
  connecting = "orange",
  connected = "green",
  error = "red",
  AUTH_TOPEER_FAILED = "red",
  NEGOTIATION_FAILED = "red"
}

setmetatable(ppp_light_map, untaint_mt)

local ppp_status
if content.uci_wan_auto ~= "0" then
  -- WAN enabled
  content.uci_wan_auto = "1"
  ppp_status = format("%s", content_rpc.wan_ppp_state) -- untaint
  if ppp_status == "" or ppp_status == "authenticating" or ppp_status == "networking" then
    ppp_status = "connecting"
  end

  if not (content_rpc.wan_ppp_error == "" or content_rpc.wan_ppp_error == "USER_REQUEST") then
    if ppp_state_map[content_rpc.wan_ppp_error] then
      ppp_status = content_rpc.wan_ppp_error
    else
      ppp_status = "error"
    end
  end
else
  -- WAN disabled
  ppp_status = "disabled"
end

ngx.print(ui_helper.createHeader(T"Internet Access", true, true))
  ngx.print('\
\
<div class="modal-body update">\
');  
local tabs = {
  {
    desc = T"IPv4 Configuration",
    active = "active",
    target = "modals/internet-modal.lp"
  },
  {
    desc =  T"IPv6 Configuration",
    target = "modals/internet-ex-modal.lp"
  }
}
ngx.print(ui_helper.createModalTabs(tabs))

if session:hasAccess("/modals/internet-"..mode_current.."-routed-configuration.lp") then
  local tab = {
    {
      desc = T"Status",
      active = "active",
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
      target = "modals/internet-"..mode_current.."-routed-settings.lp"
    }
  end
  ngx.print(ui_helper.createModalTabs(tab))
end
  ngx.print('\
<form class = "form-horizontal" method = "post" action = "modals/internet-pppoa-routed-status.lp">\
<fieldset>\
');  
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
  <legend>');  ngx.print( T"PPP connection" ); ngx.print('</legend>\
');  
      ngx.print(ui_helper.createLight(T"Status", nil, ppp_state_map[ppp_status], { light = { class = ppp_light_map[ppp_status] } } ))
  ngx.print('\
</fieldset>\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 