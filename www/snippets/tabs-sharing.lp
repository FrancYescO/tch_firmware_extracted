--pretranslated: do not change this file
 ngx.print('\
');  
gettext.textdomain('webui-contentsharing')

local ui_helper = require("web.ui_helper")
local postHelper = require("web.post_helper")
local session = ngx.ctx.session
local role = session:getrole()
local items = {
  {"contentsharing-modal.lp", T"Content Sharing"},
}

if postHelper.isFeatureEnabled("printerEnable", role) then
 items[#items + 1] = {"printersharing-modal.lp", T"Printer Sharing"}
end

local uri = ngx.var.args and string.len(ngx.var.args) > 0 and ngx.var.uri.. "?" .. ngx.var.args or  ngx.var.uri

local html = ui_helper.createModalTabs(items, uri)
ngx.print(html)

  ngx.print('\
\
'); 