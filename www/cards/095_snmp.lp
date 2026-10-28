--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session

-- WAN services data
local snmpd = {
  enable = "uci.snmpd.general.enabled",
}
content_helper.getExactContent(snmpd)

local snmpstate = T"SNMP Disabled"
local snmpled = "0"
if session:hasAccess("/modals/snmpd-global-modal.lp") then
    if snmpd["enable"] == "1" then
      snmpstate = T"SNMP Enabled"
      snmpled = "1"
    end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"SNMP", "modals/snmpd-global-modal.lp") ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf13e;">\
      ');  ngx.print(ui_helper.createSimpleLight(snmpled, snmpstate, { light = { id = "SNMP_Status_Led" }, span = { id = "SNMP_Status" } }),
     '<p></p>')  ngx.print('\
    </div>\
  </div>\
</div>\
');  end   ngx.print('\
'); 