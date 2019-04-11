--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local dyntab_helper = require("web.dyntab_helper")

local bmh = require("broadbandmode_helper")
local tabdata
if bmh.broadBandDetails then
  tabdata = dyntab_helper.process(bmh.broadBandDetails())
else
  tabdata = dyntab_helper.process(bmh)
end
local session = ngx.ctx.session

if tabdata and tabdata.current.card then
  if not session:hasAccess("/modals/broadband-modal.lp") and not session:isdefaultuser() then
     return
  end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
');  
    lp.setpath("/www/cards/snippets/")
    lp.include(tabdata.current.card)
    -- have to bring it back to original value ... singleton
    lp.setpath("/www/cards/")
  ngx.print('\
  </div>\
</div>\
');  end   ngx.print('\
'); 