--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  
gettext.textdomain('webui-core')

local ipairs, string, table = ipairs, string, table
local proxy = require("datamodel")

local items = {
    {"diagnostics-xdsl-modal.lp", T"xDSL"},
    {"diagnostics-ping-modal.lp", T"Ping & Traceroute"},
    {"diagnostics-connection-modal.lp", T"Connection"},
    {"diagnostics-network-modal.lp", T"Network"},
    {"logviewer-modal.lp", T"Log viewer"},
}

if ngx.ctx.session:getrole()=="guest" then
    items[#items+1] = {"diagnostics-tcpdump-modal.lp", T"Tcpdump"}
end

local html = {}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

for _,v in ipairs(items) do
    local active = ""
    if uri == ("/modals/" .. v[1]) then
        active = "active"
    end

    html[#html+1] = string.format('<li class="%s"><a id="%s" href="#" data-remote="/modals/%s">%s</a></li>', active, v[2], v[1], v[2])
end
ngx.print(html)

  ngx.print('\
\
</ul>\
'); 