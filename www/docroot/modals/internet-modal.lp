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
local post_helper = require("web.post_helper")

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

--Connect/Disconnet button
local wan_auto
if mode_active ~= "default" then
   wan_auto = format("%s", wan_info.auto)
else
   wan_auto = format("%s", ppp_info.auto)
end
local content1
if ngx.var.request_method == "POST" then
    content1 = ngx.req.get_post_args()
    action = content1["action"]
    if action == "CONNECT" then
      if mode_active ~= "default" then
        if wan_auto ~= "0" then
            proxy.set("uci.network.interface.@wan.auto", "0" )
        else
            proxy.set("uci.network.interface.@wan.auto", "1" )
        end
      else
        if wan_auto ~= "0" then
            proxy.set("uci.network.interface.@ppp.auto", "0" )
        else
            proxy.set("uci.network.interface.@ppp.auto", "1" )
        end
      end
      proxy.apply()
    end
end

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
    local connect_button = {
        button = {
            ["data-name"] = "action",
            ["data-value"] = "CONNECT",
        }
    }

    local attr = {
        span = {
              class = "span4",
        }
    }

    html[#html+1] = ui_helper.createLabel(T"Current Mode", mode_data[mode_active].description, attr)
    if wan_auto ~= "0" then
        html[#html+1] = ui_helper.createButton("WAN Connection", "Disconnect", "icon-cog", connect_button)
    else
        html[#html+1] = ui_helper.createButton("WAN Connection", "Connect", "icon-cog", connect_button)
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