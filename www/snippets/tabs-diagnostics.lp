--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local ipairs, string = ipairs, string
local format = string.format
local lfs = require("lfs")
local proxy = require("datamodel")
local checkgpon = require("checkgponboard_helper")
local is_gpon = checkgpon.isGPONBoard()
local post_helper = require("web.post_helper")
local wanIntf = post_helper.getActiveInterface()
local session = ngx.ctx.session
local role = session:getrole()
local items = {}

items[#items + 1] = {"diagnostics-ping-modal.lp", T"Ping & Traceroute"}
items[#items + 1] = {"diagnostics-network-modal.lp", T"Network"}

if post_helper.isFeatureEnabled("diagnosticsIgmpProxy", role) then
  items[#items + 1] = {"diagnostics-igmpproxy-modal.lp", T"Igmpproxy"}
end
if post_helper.isFeatureEnabled("diagnosticsGraphingAndTcp", role) then
  items[#items + 1] = {"diagnostics-tcpdump-modal.lp", T"Tcpdump"}
  items[#items + 1] = {"diagnostics-graphs-modal.lp", T"Graphing"}
end
if post_helper.isFeatureEnabled("diagnosticsTcp", role) then
  if role == "engineer" then
    items[#items + 1] = {"diagnostics-tcpdump-modal.lp", T"Tcpdump"}
  end
end

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end

local html = {}

for _, v in ipairs(items) do
    local active = ""
    if uri == ("/modals/" .. v[1]) then
        active = "active"
    end
    html[#html+1] = string.format('<li class="%s"><a id ="%s" href="#" data-remote="/modals/%s">%s</a></li>', active, v[2], v[1], v[2])
end
ngx.print(html)

  ngx.print('\
</ul>\
'); 