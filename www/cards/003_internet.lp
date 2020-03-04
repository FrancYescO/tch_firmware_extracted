--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local dyntab_helper = require("web.dyntab_helper")

local imh = require("internetmode_helper").get()
local tabdata = dyntab_helper.process(imh)

ngx.ctx.session:store("network_interface_name", "wan")
local ui_helper = require("web.ui_helper")

-- Display the card but do not give access if not allowed
local switchName = nil
local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    switchName = "uci_wan_auto"
    modalPath = "/modals/internet-modal.lp"
end

local content_helper = require("web.content_helper")
local content_params = {
    variant = "uci.env.var.iinet_variant",
}
content_helper.getExactContent(content_params)
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
        ');  ngx.print( ui_helper.createCardHeader(T"Internet", modalPath) ); ngx.print('\
        <div class="content">\
          <div class="divtable">\
          ');  
		  lp.setpath("/www/cards/snippets/")
          if content_params.variant ~= "novas" then
		    lp.include("003_internet_wan_sensing.lp")
          end
		  lp.include("003_internet_pvc_vlan.lp")
		  lp.include(tabdata.current.card)
		  lp.setpath("/www/cards/")
		    ngx.print('\
           </div>\
         </div>\
  </div>\
</div>\
'); 