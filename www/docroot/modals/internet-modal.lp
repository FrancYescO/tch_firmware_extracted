--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local proxy = require("datamodel")
local lp = require("web.lp")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local currentuserrole = ngx.ctx.session:getrole()

function processOperations(operations)
    if type(operations) ~= "table" then
        return
    end

    local success, msg
    for _,v in ipairs(operations) do
        local path = v[1]
        local val = v[2]

        success, msg = proxy.set(path, val)
    end
end

-- Process POST query

-- Process the selected mode if any
local imh = require("internetmode_helper")

local mode_options = {}
local mode_data = {}
local mode_default = "" -- the default mode to use
local mode_active = ""  -- the mode currently in use (mode_default if not set), for telstra, no select supported

for _,v in ipairs(imh) do
    mode_options[#mode_options + 1] = { v.name, v.description }
    mode_data[v.name] = v
    if v.default == true then
        mode_default = v.name
    end
end

mode_active = format("%s", proxy.get("uci.network.config.wan_mode")[1].value) -- remove tainting
local wan_info = {
    proto = "uci.network.interface.@wan.proto",
    auto = "uci.network.interface.@wan.auto",
}
local ppp_info = {
    proto = "uci.network.interface.@ppp.proto",
    auto = "uci.network.interface.@ppp.auto",
}
content_helper.getExactContent(wan_info)
content_helper.getExactContent(ppp_info)


if mode_active == "" then
    mode_active = format("%s",wan_info.proto)
end

if mode_active == "" then
    mode_active = "default"
end

local supervision_modes = {
    { "BFD", T"BFD" },
    { "Disabled", T"Disabled" },
}

local supervision_modes_param = {
    supervision_mode = "uci.supervision.global.mode",
    supervision_enabled = "uci.supervision.global.enabled",
}

local supervision_modes_valid = {
    supervision_mode = gVIES(supervision_modes),
    supervision_enabled = vB,
}

local content = post_helper.handleQuery(supervision_modes_param, supervision_modes_valid)
local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Internet Access", true, true, 20, help_link) ); ngx.print('\
\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/internet-modal.lp">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
\
<fieldset id="conn_mode" class="advanced hide">\
<legend>');  ngx.print( T"Connection mode" ); ngx.print('</legend>\
\
');  
    local html = {}

    local attr = {
        span = {
              class = "span4",
        }
    }

    html[#html+1] = ui_helper.createLabel(T"Current Mode", mode_data[mode_active].description, attr)
    if mode_active == "dhcp" then
        if currentuserrole == "guest" then
            html[#html+1] = ui_helper.createInputSelect(T"WAN Supervision", "supervision_mode", supervision_modes, content["supervision_mode"])
            html[#html+1] = ui_helper.createSwitch(T"Supervision Enabled", "supervision_enabled", content["supervision_enabled"])
        else
            html[#html+1] = ui_helper.createLabel(T"WAN Supervision", content["supervision_mode"])
            enabled_map = (content["supervision_enabled"] == "0") and "Disabled" or "Enabled"
            html[#html+1] = ui_helper.createLabel(T"Supervision Enabled", enabled_map)
        end
    end

    ngx.print(html)
  ngx.print('\
</fieldset>\
\
');  
    lp.setpath("/www/snippets/")
    lp.include(mode_data[mode_active].view)
  ngx.print('\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 