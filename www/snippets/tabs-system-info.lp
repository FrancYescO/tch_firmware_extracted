--pretranslated: do not change this file
 ngx.print('\
');  
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local items = {
  {"system-info-modal.lp", T"Global Information"},
  {"time-management-modal.lp", T"Time Management"},
  {"system-config-modal.lp", T"Configuration"},
}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end

local html = ui_helper.createModalTabs(items, uri)
ngx.print(html)

  ngx.print('\
\
'); 