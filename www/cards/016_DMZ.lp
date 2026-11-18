--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

-- WAN services data
local wan_services_data = {
  dmz_enable = "rpc.network.dmz.enabled",
}
content_helper.getExactContent(wan_services_data)

local session = ngx.ctx.session
if session:hasAccess("/modals/dmz-modal.lp") then
    local dmzstate
    local dmzled
    if wan_services_data["dmz_enable"] == "1" then
      dmzstate = T"Bridge ETH port 4 enabled"
      dmzled = "1"
    else
      dmzstate = T"Bridge ETH port 4 disabled"
      dmzled = "0"
    end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"Bridge ETH port 4", "modals/dmz-modal.lp") ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf13e;">\
    ');  ngx.print(
            ui_helper.createSimpleLight(dmzled, dmzstate, { light = { id = "DMZ_Status_Led" }, span = { id = "DMZ_Status" } }),
            '<p></p>'
        )
      ngx.print('\
    </div>\
  </div>\
</div>\
');  
end
  ngx.print('\
'); 