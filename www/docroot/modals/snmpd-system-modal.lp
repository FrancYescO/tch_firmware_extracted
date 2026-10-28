--pretranslated: do not change this file
 
  -- Localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local ui_helper = require("web.ui_helper")
  local post_helper = require("web.post_helper")
  local message_helper = require("web.uimessage_helper")
  local andValidation = post_helper.getAndValidation
  local validateStringLength = post_helper.getValidateStringLengthInRange(1, 255)
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")

  local mapParams = {
    location = "uci.snmpd.system.@system[0].sysLocation",
    contact = "uci.snmpd.system.@system[0].sysContact",
    name = "uci.snmpd.system.@system[0].sysName",
    services = "uci.snmpd.system.@system[0].sysServices",
    description = "uci.snmpd.system.@system[0].sysDescr",
    objectID = "uci.snmpd.system.@system[0].sysObjectID"
  }
  local mapValid = {
    location = andValidation(validateStringLength, post_helper.isSpaceInString),
    contact = andValidation(validateStringLength, post_helper.isSpaceInString),
    name = andValidation(validateStringLength, post_helper.isSpaceInString),
    services = andValidation(validateStringLength, post_helper.isSpaceInString),
    description = validateStringLength,
    objectID = andValidation(validateStringLength, post_helper.isSpaceInString)
  }

  local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  ngx.print(ui_helper.createHeader(T"System", false, true))  ngx.print('\
\
<form class = "modal-body form-horizontal" method = "post" action = "modals/snmpd-system-modal.lp">\
  ');  lp.include("tabs-snmpd.lp")  ngx.print('\
  ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))  ngx.print('\
  <fieldset>\
    <legend>');  ngx.print( T"Configuration" ); ngx.print('</legend>\
    ');  
      ngx.print(
        ui_helper.createInputText(T"Location", "location", content.location, {}, helpmsg.location),
        ui_helper.createInputText(T"Contact", "contact", content.contact, {}, helpmsg.contact),
        ui_helper.createInputText(T"Name", "name", content.name, {}, helpmsg.name),
        ui_helper.createInputText(T"Services", "services", content.services, {}, helpmsg.services),
        ui_helper.createInputText(T"Description", "description", content.description, {}, helpmsg.description),
        ui_helper.createInputText(T"Object ID", "objectID", content.objectID, {}, helpmsg.objectID)
      )
      ngx.print('\
  </fieldset>\
</form>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 