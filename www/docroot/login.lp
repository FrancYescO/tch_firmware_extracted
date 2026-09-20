--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")

lp.setpath("/www/docroot/")
lp.include(require("telstra_helper").login_file)
  ngx.print('\
'); 