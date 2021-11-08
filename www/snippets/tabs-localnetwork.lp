--pretranslated: do not change this file
 ngx.print('\
');  
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local items = {
  {"ethernet-modal.lp", T"Lan"},
  {"iproutes-modal.lp", T"IP Extras"}
}

local uri = ngx.var.args and string.len(ngx.var.args) > 0 and ngx.var.uri.. "?" .. ngx.var.args or  ngx.var.uri

local html = ui_helper.createModalTabs(items, uri)
ngx.print(html)

  ngx.print('\
\
'); 