--pretranslated: do not change this file
 ngx.print('\
');  
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session
local role = session:getrole()
local items = {
  {"wanservices-modal.lp", T"Port Mapping"},
}

if session:hasAccess("/modals/dyndns-wanservices-modal.lp") then
  items[#items+1] = {"dyndns-wanservices-modal.lp", T"DNS & DynDNS"}
end

if (role == "engineer" or role == "superuser" or role == "ispuser") then
  items[#items+1] = {"nat-alg-helper-modal.lp", T"Settings"}
end

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end

local html = ui_helper.createModalTabs(items, uri)
ngx.print(html)

  ngx.print('\
\
'); 