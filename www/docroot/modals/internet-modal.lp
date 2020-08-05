--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")

local imh = require("internetmode_helper")

local tabdata = dyntab_helper.process(imh)

local mode_current = tabdata.current.name
local mode_options = tabdata.options

local wan_ppp_ll_intf = proxy.get("rpc.network.interface.@wan.ppp.ll_intf")[1].value
local wan_ppp_over_atm = proxy.get(string.format("uci.xtm.atmdevice.@%s.", wan_ppp_ll_intf)) ~= nil
if not wan_ppp_over_atm then
   for k,v in ipairs(mode_options) do
       if v[1] == "pppoa" then
           table.remove(mode_options, k)
           break
       end
   end
end

    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
ngx.print(ui_helper.createHeader(T"Internet Access", false, false), '\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/internet-modal.lp">',
ui_helper.createMessages(message_helper.popMessages()));
end
    lp.setpath("/www/snippets/")
    lp.include(tabdata.current.view)
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
ngx.print('\
</form>\
</div>',
ui_helper.createFooter());

end
