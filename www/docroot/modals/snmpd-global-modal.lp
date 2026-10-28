--pretranslated: do not change this file
 
  -- Localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local ui_helper = require("web.ui_helper")
  local post_helper = require("web.post_helper")
  local validateBoolean = post_helper.validateBoolean
  local message_helper = require("web.uimessage_helper")
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")

  local mapParams = {
    snmpEnable = "uci.snmpd.general.enabled",
  }
  local mapValid = {
    snmpEnable = validateBoolean,
  }

  local params, _ = post_helper.handleQuery(mapParams, mapValid)

  ngx.print(ui_helper.createHeader(T"SNMP Info", false, true))  ngx.print('\
\
<form class = "modal-body form-horizontal" method = "post" action = "modals/snmpd-global-modal.lp">\
  ');  lp.include("tabs-snmpd.lp")  ngx.print('\
  ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))  ngx.print('\
  <fieldset>\
    <legend>');  ngx.print( T"Configuration" ); ngx.print('</legend>\
      ');  
        ngx.print(ui_helper.createSwitch(T"SNMP Enabled", "snmpEnable", (params.snmpEnable == "1" and "1" or "0")))
        ngx.print('\
  </fieldset>\
</form>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 