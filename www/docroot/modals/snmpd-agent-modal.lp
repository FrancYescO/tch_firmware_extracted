--pretranslated: do not change this file
 
  -- Localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local ui_helper = require("web.ui_helper")
  local post_helper = require("web.post_helper")
  local message_helper = require("web.uimessage_helper")
  local validAddr = post_helper.getValidateInEnumSelect({{"UDP:161"}, {"UDP6:161"}})
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")

  local mapParams = {
    agentAddress = "uci.snmpd.agent.@agent[0].agentaddress"
  }
  local mapValid = {
    agentAddress = validAddr
  }

  local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  ngx.print(ui_helper.createHeader(T"Agent", false, true))  ngx.print('\
\
<form class = "modal-body form-horizontal" method = "post" action = "modals/snmpd-agent-modal.lp">\
  ');  lp.include("tabs-snmpd.lp")  ngx.print('\
  ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))  ngx.print('\
  <fieldset>\
    <legend>');  ngx.print( T"Configuration" ); ngx.print('</legend>\
    ');  ngx.print(ui_helper.createInputText(T"Agent Address", "agentAddress", content.agentAddress, {}, helpmsg.agentAddress))   ngx.print('\
  </fieldset>\
</form>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 