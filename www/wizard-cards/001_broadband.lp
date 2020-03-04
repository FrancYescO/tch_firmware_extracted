--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-wizard')

local content_helper = require("web.content_helper")
local lp = require("web.lp")

local param_content = {
    variant = "uci.env.var.iinet_variant",
}
content_helper.getExactContent(param_content)
lp.setpath("/www/wizard-cards/snippets/")
if param_content.variant == "novas" then
  lp.include("broadband_novas.lp")
else
  lp.include("broadband_non_novas.lp")
end
lp.setpath("/www/wizard-cards/")
  ngx.print('\
'); 