--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

ngx.ctx.session:store("network_interface_name", "wan6")

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local post_helper = require("web.post_helper")
local session = ngx.ctx.session
local role = session:getrole()
local imh = require("internetmode_ex_helper")
local tabdata = dyntab_helper.process(imh)

if not tabdata.current.ajax then
  -- only display if not doing an ajax request
  ngx.print('\
\
<form class="form-horizontal" method="post" action="modals/internet-ex-modal.lp">\
\
');  
  lp.setpath("/www/docroot/modals/")
  lp.include(tabdata.current.view)
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
</form>\
');  else   ngx.print('\
  ');  return   ngx.print('\
');  end   ngx.print('\
'); 