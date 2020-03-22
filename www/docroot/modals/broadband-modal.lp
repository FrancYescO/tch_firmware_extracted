--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local content_helper = require("web.content_helper")

local bmh = require("broadbandmode_helper")
local tabdata = dyntab_helper.process(bmh)

local mode_current = tabdata.current.name
local mode_options = tabdata.options

  ngx.print('\
');  
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Broadband", true, true))   ngx.print('\
\
<div class="modal-body update">\
');  
    local content_type = {
        l2 = "uci.wansensing.global.l2type",
    }
    content_helper.getExactContent(content_type)
    local session = ngx.ctx.session

    if content_type.l2 == "ETH" or content_type.l2 == "VDSL" and session:hasAccess("/modals/broadband-eth-modal.lp") then
        local lp = require("web.lp")
        lp.setpath("/www/snippets/")
        lp.include("tabs-broadband.lp")
    end
  ngx.print('\
\
<form class="form-horizontal" method="post" action="modals/broadband-modal.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<!--\
');  
    if #bmh > 1 then
    -- Only included if there are 2 or more connection modes
  ngx.print('\
<fieldset id="conn_mode" class="advanced hide">\
<legend>');  ngx.print( T"Broadband type" ); ngx.print('</legend>\
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
    html[#html+1] = ui_helper.createButton("", "Switch connection mode", "icon-cog", mode_button)

    ngx.print(html)
  ngx.print('\
</fieldset>\
\
');  end   ngx.print('\
-->\
\
');  end   ngx.print('\
');  
    lp.setpath("/www/snippets/")
    lp.include(tabdata.current.view)
  ngx.print('\
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
\
'); 