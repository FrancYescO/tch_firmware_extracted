--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  

gettext.textdomain('webui-core')

local ipairs, string, table = ipairs, string, table

local content_helper = require("web.content_helper")
local content_type = {
    l2 = "uci.wansensing.global.l2type",
}
content_helper.getExactContent(content_type)

local items = {}
if content_type.l2 == "ETH" or content_type.l2 == "VDSL" then
    items = {
        {"broadband-modal.lp", T"Physical link status"},
        {"broadband-eth-modal.lp", T"VLAN"},
    }
else
    items = {
        {"broadband-modal.lp", T"Physical link status"},
        {"broadband-eth-modal.lp", T"PVC"},
    }
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

    html[#html+1] = string.format('<li class="%s"><a href="#" data-remote="/modals/%s">%s</a></li>', active, v[1], v[2])
end
ngx.print(html)

  ngx.print('\
\
</ul>\
'); 