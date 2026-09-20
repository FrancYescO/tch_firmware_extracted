--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local format = string.format

-- Non-configurable data
local cs = {
    uci_wan_auto = "uci.network.interface.@wan.auto",
    ipaddr = "rpc.network.interface.@wan.ipaddr",
}

content_helper.getExactContent(cs)

-- Figure out interface state
local static_state = "disabled"
local static_state_map = {
    disabled = T"Interface Disabled",
    connected = T"Interface Enabled",
}

local static_light_map = {
  disabled = "off",
  connected = "green",
}

if cs["uci_wan_auto"] ~= "0" and cs["ipaddr"]:len() > 0 then
    cs["uci_wan_auto"] = "1"
    static_state = "connected"
end


local modalPath = "/modals/internet-modal.lp"

local session = ngx.ctx.session


ngx.print(ui_helper.createCardHeader(T"Internet Access", modalPath), '\
<div class="content card_bg" data-bg-text="&#xf0ac;">\
   <div class="divtable">',
   	ui_helper.createSimpleLight(nil, static_state_map[static_state], { light = { class = static_light_map[static_state] } }), '\
  	<p class="subinfos">');
     	if static_state == "connected" then
            ngx.print(format(T"Fixed IP : <strong>%s</strong>", cs["ipaddr"]))
        end
     ngx.print('\
  </p>\
</div>\
</div>');