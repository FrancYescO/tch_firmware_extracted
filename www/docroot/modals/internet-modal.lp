--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")

local internetmode_helper = require("internetmode_helper")
local imh = internetmode_helper.getvalue()

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

  ngx.print('\
\
');  
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Internet Access", true, true))   ngx.print('\
\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/internet-modal.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
');  
    if #imh > 1 then
    -- Only included if there are 2 or more connection modes
  ngx.print('\
<fieldset id="conn_mode" class="advanced hide">\
<legend>');  ngx.print( T"Connection mode" ); ngx.print('</legend>\
\
');  
    local html = {}

    local mode_attributes = {
        radio = {
            class = "inline"
        },
        input = {
            class = "no-save",
            ["data-for"] = "SWITCH_MODE",
        }
    }
    local mode_button = {
        button = {
            ["data-name"] = "action",
            ["data-value"] = "SWITCH_MODE",
        }
    }

    html[#html+1] = ui_helper.createInputRadio(T"Mode", "newmode", mode_options, mode_current, mode_attributes)
    html[#html+1] = ui_helper.createButton("", T"Switch connection mode", "icon-cog", mode_button)

    ngx.print(html)
  ngx.print('\
</fieldset>\
\
');  end   ngx.print('\
\
');  end   ngx.print('\
');  
    lp.setpath("/www/snippets/")
    lp.include(tabdata.current.view)
  ngx.print('\
\
');  
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
  ngx.print('\
\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
');  end   ngx.print('\
'); 