--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local session = ngx.ctx.session
local role = session:getrole()
local dyntab_helper = require("web.dyntab_helper")
local imh = require("internetmode_ex_helper")
local tabdata = dyntab_helper.process(imh)
local mode_current = tabdata.current.name


ngx.print(ui_helper.createHeader(T"Internet Access", true, true))
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<div class="modal-body update">\
');  
local tabs = {
  {
    desc = T"IPv4 Configuration",
    target = "modals/internet-modal.lp"
  },
  {
    desc = T"IPv6 Configuration",
    active = "active",
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
    },
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
<form class = "form-horizontal" method = "post" action = "modals/internet-6rd-routed-status.lp">\
<fieldset>\
  <legend>');  ngx.print( T"6rd configuration" ); ngx.print('</legend>\
');  
  local html = {}
  if mode_current == "6rd" then
    html[#html+1] = ui_helper.createLabel(T"Connection Mode", T"6rd")
  end
  ngx.print(html)
  ngx.print('\
</fieldset>\
</div>\
</form>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 