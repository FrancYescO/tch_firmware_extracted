--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local content_helper = require("web.content_helper")

local content_params = {
    variant = "uci.env.var.iinet_variant"
}
content_helper.getExactContent(content_params)

if content_params.variant == "novus" then

ngx.ctx.session:store("network_interface_name", "wan")
local ui_helper = require("web.ui_helper")

-- Display the card but do not give access if not allowed
local switchName = nil
local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/ipoe-modal.lp") then
    switchName = "uci_wan_auto"
    modalPath = "/modals/ipoe-modal.lp"
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
        ');  ngx.print( ui_helper.createCardHeader(T"IPoE connection", modalPath) ); ngx.print('\
        <div class="content">\
          <div class="divtable">\
          ');  
		  lp.setpath("/www/cards/snippets/")
		  lp.include("003_ipoe_pvc_vlan.lp")
		  lp.include("003_internet_ipoe_routed.lp")
		  lp.setpath("/www/cards/")
		    ngx.print('\
           </div>\
         </div>\
  </div>\
</div>\
');  end  ngx.print('\
'); 