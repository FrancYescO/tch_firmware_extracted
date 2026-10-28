--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsList()
local validateDMZ = post_helper.validateDMZ
local vB = post_helper.validateBoolean
local qry_params = {
  DMZ_enable = "rpc.network.firewall.dmz.enable",
  DMZ_destinationip = "rpc.network.firewall.dmz.redirect.dest_ip"
}
local qry_valid = {
    DMZ_enable = vB,
    DMZ_destinationip = validateDMZ
}
local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)
  ngx.print('\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/dmz-macmodal.lp">\
    ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))  ngx.print('\
    <fieldset class="">\
      <legend>');  ngx.print( T"DMZ" ); ngx.print('</legend>\
      ');  
        -- Switch for toggling DMZ state
        local dmzipattr = {
            autocomplete = hosts_ac
        }
        local DMZ_destinationmac = {
          "rpc.network.firewall.dmz.redirect.dest_mac",
        }
        content_helper.getExactContent(DMZ_destinationmac)
        ngx.print(ui_helper.createSwitch(T"Enabled", "DMZ_enable", qry_data["DMZ_enable"], nil, qry_helpmsg["DMZ_enable"]),
                  ui_helper.createInputText(T"Destination IP", "DMZ_destinationip", qry_data["DMZ_destinationip"], dmzipattr, qry_helpmsg["DMZ_destinationip"]),
                  ui_helper.createLabel(T"Destination MAC", DMZ_destinationmac[1]))
        ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 