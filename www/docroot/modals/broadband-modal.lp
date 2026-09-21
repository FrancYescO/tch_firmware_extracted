--pretranslated: do not change this file
 
-- Enable localization
-- GHG-1541 Broadband card/modal
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")

local bmh = require("broadbandmode_helper")
local tabdata
local availableConnections
if bmh.broadBandDetails then
  tabdata = dyntab_helper.process(bmh.broadBandDetails())
  availableConnections = bmh.broadBandDetails()
else
  tabdata = dyntab_helper.process(bmh)
  availableConnections = bmh
end

local mode_current = tabdata.current.name
local mode_options = tabdata.options

local content_helper = require("web.content_helper")
local format = string.format
local wanParam = { 
			wans_l2type		= "uci.wansensing.global.l2type",
			link_eth		= "sys.class.net.@eth4.operstate",
    			link_adsl_vdsl		= "sys.class.xdsl.@line0.Status",
			
		}
			
content_helper.getExactContent(wanParam)

local L2type = format("%s", wanParam.wans_l2type)
local LinkETH = format("%s", wanParam.link_eth)
local LinkADSLVDSL = format("%s", wanParam.link_adsl_vdsl)

local State_eth = "Disabled"
local State_adsl = "Disabled"
local State_vdsl = "Disabled"
	
	if L2type == "ETH" and LinkETH == "up" then
		State_eth = "Connected"

	elseif L2type == "ETH" then	
		State_eth="Enabled"
	
	elseif L2type == "ADSL" and LinkADSLVDSL == "Up" then
		State_adsl="Connected"
	
	elseif L2type == "ADSL" then
  		State_adsl="Enabled"
		
	elseif L2type == "VDSL" and LinkADSLVDSL == "Up" then
		State_vdsl="Connected"
	
	elseif L2type == "VDSL" then
  		State_vdsl="Enabled"
	
end


local state_map = {
	Disabled = T"Disabled",
	Enabled = T"Enabled",
	Connected = T"Connected",
}


local light_map = {
	Disabled = "off",
	Enabled = "orange",
	Connected = "green",
}

  ngx.print('\
');  
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request
  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Broadband", true, true))   ngx.print('\
\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/broadband-modal.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
');  
    if #availableConnections > 1 then
    -- Only included if there are 2 or more connection modes
  ngx.print('\
<fieldset id="conn_mode" class="advanced hide">\
<legend>');  ngx.print( T"Broadband type" ); ngx.print('</legend>\
\
');  
    local html = {}
	
	html[#html + 1] = ui_helper.createLight(T"Ethernet", nil, state_map[State_eth], { light = { class = light_map[State_eth] } })
	html[#html + 1] = ui_helper.createLight(T"ADSL2+", nil, state_map[State_adsl], { light = { class = light_map[State_adsl] } })
	html[#html + 1] = ui_helper.createLight(T"VDSL", nil, state_map[State_vdsl], { light = { class = light_map[State_vdsl] } })
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