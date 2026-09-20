--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format

local content_eth = {
  ethwan_status = "sys.eth.port.@eth4.status",
  ethwan_linkrate = "sys.eth.port.@eth4.speed",
}
-- Get the content
content_helper.getExactContent(content_eth)

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Broadband", true, true, nil, help_link) ); ngx.print('\
\
<div class="modal-body update">\
');  
    local html = {}
    local tabs = {
        {
            desc = T"DSL link status",
            target = "modals/broadband-modal.lp",
        },
        {
            desc = T"Ethernet link status",
            active = "active",
            target = "modals/broadband-eth-modal.lp",
        },
        {
            desc = T"DSL Diagnostics",
            target = "modals/diagnostics-xdsl-modal.lp?entry=bb",
        },
    }
    table.insert (html, ui_helper.createModalTabs(tabs))
    ngx.print (html)
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/broadband-eth-modal.lp">\
    <fieldset>\
      ');  
        local html = {}

        -- Icons
        local statusIcon
        if content_eth["ethwan_status"] == "up" then
          statusIcon = "<div class=\"light green\"></div>"
          content_eth["ethwan_status"] = "Up"
        else
          statusIcon = "<div class=\"light red\"></div>"
          content_eth["ethwan_status"] = "Down"
        end

        -- Display the ethernet wan status
        html[#html + 1] = ui_helper.createLabel(T"Ethernet Status",format("%s%s", statusIcon, T(content_eth["ethwan_status"])))
        if content_eth["ethwan_status"] == "Up" then
           html[#html + 1] = ui_helper.createLabel(T"Link Rate", T(content_eth["ethwan_linkrate"] .. "M"))
        end

        ngx.print(html)
        ngx.print('\
    </fieldset>\
    </form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 