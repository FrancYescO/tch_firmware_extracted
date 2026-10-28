--pretranslated: do not change this file
 
  -- Localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local ui_helper = require("web.ui_helper")
  local post_helper = require("web.post_helper")
  local andValidation = post_helper.getAndValidation
  local validateStringLength = post_helper.getValidateStringLengthInRange(1, 255)
  local message_helper = require("web.uimessage_helper")
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")

  local mapParams = {
    bittCommunity = "uci.snmpd.private.community",
    bittSource = "uci.snmpd.private.source",
    bittSecname = "uci.snmpd.private.secname",
    baitCommunity = "uci.snmpd.public.community",
    baitSource = "uci.snmpd.public.source",
    baitSecname = "uci.snmpd.public.secname"
  }
  local mapValid = {
    bittCommunity = andValidation(validateStringLength, post_helper.isSpaceInString),
    bittSource = andValidation(validateStringLength, post_helper.isSpaceInString),
    bittSecname = andValidation(validateStringLength, post_helper.isSpaceInString),
    baitCommunity = andValidation(validateStringLength, post_helper.isSpaceInString),
    baitSource = andValidation(validateStringLength, post_helper.isSpaceInString),
    baitSecname = andValidation(validateStringLength, post_helper.isSpaceInString),
  }

  local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  ngx.print(ui_helper.createHeader(T"Com2sec", false, true))  ngx.print('\
\
<form class = "modal-body form-horizontal" method = "post" action = "modals/snmpd-com2sec-modal.lp">\
  ');  lp.include("tabs-snmpd.lp")  ngx.print('\
  ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))  ngx.print('\
  <fieldset>\
    <legend>');  ngx.print( T"bitt" ); ngx.print('</legend>\
    ');  
      ngx.print(
        ui_helper.createInputText(T"Community", "bittCommunity", content.bittCommunity, {}, helpmsg.bittCommunity),
        ui_helper.createInputText(T"Source", "bittSource", content.bittSource, {}, helpmsg.bittSource),
        ui_helper.createInputText(T"SecName", "bittSecname", content.bittSecname, {}, helpmsg.bittSecname)
      )
      ngx.print('\
  </fieldset>\
  <fieldset>\
    <legend>');  ngx.print( T"bait" ); ngx.print('</legend>\
    ');  
      ngx.print(
        ui_helper.createInputText(T"Community", "baitCommunity", content.baitCommunity, {}, helpmsg.baitCommunity),
        ui_helper.createInputText(T"Source", "baitSource", content.baitSource, {}, helpmsg.baitSource),
        ui_helper.createInputText(T"SecName", "baitSecname", content.baitSecname, {}, helpmsg.baitSecname)
      )
      ngx.print('\
  </fieldset>\
</form>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 