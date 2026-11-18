--pretranslated: do not change this file
 
---
--- ENABLE LOCALIZATION
---
gettext.textdomain('webui-core')

---
--- REQUIRED LIBRARIES
---
--- content_helper: extracts information from the data model / uci layer
--- ui_helper:      controls creation of web ui widgets (switches, text entry, radio buttons, etc)
--- post_helper:    controls behavior of POST messages sent from web ui to Transformer
--- proxy:          used for access to the data model / uci layer (get and set methods)
--- message_helper: produces human readable content in the web ui (e.g. errors, success prompts)
---
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local session = ngx.ctx.session
local role = session:getrole()
local dyntab_helper = require("web.dyntab_helper")
local imh = require("internetmode_helper").get()
local tabdata = dyntab_helper.process(imh)
local mode_current = tabdata.current.name


ngx.print(ui_helper.createHeader(T"Internet Access", true, true))
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
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
    desc = T"IPv6 Configuration",
    target = "modals/internet-ex-modal.lp"
   },
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
<form class = "form-horizontal" method = "post" action = "modals/internet-static-routed-status.lp">\
<fieldset>\
    <legend>');  ngx.print( T"Static Connection" ); ngx.print('</legend>\
  ');  
    local html = {}
    if mode_current == "static" then
      html[#html+1] = ui_helper.createLabel(T"Connection Mode", T"Fixed IP Mode")
    end
    ngx.print(html)
    ngx.print('\
</fieldset>\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 