--pretranslated: do not change this file
 ngx.print('<ul class="nav nav-tabs">\
\
');  

gettext.textdomain('webui-telstra')

local ipairs, string = ipairs, string
local session = ngx.ctx.session
local items = {}
if session:hasAccess("/dyndns.lp") then
  items[#items + 1] = {"dyndns.lp", T"Dynamic DNS"}
end
items[#items + 1] = {"portforwarding.lp", T"Port Forwarding"}
items[#items + 1] = {"remoteaccess.lp", T"Remote Web Access"}
items[#items + 1] = {"traffic.lp?iface=wl0", T"Traffic Monitor"}
local html = {}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?iface=wl0"
end

for _,v in ipairs(items) do
    local active = ""
    if uri == ("/" .. v[1]) then
        active = "active"
    end

    html[#html+1] = string.format('<li class="%s"><a id="%s" href="%s" target="_self">%s</a></li>', active, v[2], v[1], v[2])
end
ngx.print(html)

  ngx.print('\
\
</ul>\
'); 