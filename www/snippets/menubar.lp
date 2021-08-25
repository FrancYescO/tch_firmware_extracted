--pretranslated: do not change this file
 ngx.print('<div class="container">\
    <div class="row">\
        <div class="menubar">\
\
');  
    gettext.textdomain('webui-telstra')

    local format = string.format
    local untaint_mt = require("web.taint").untaint_mt
    local setmetatable = setmetatable
    local session = ngx.ctx.session
    local items = {
        {"/home.lp", "home", T"HOME",
         setmetatable({ ["/home.lp"] = true, ["/booster.lp"] = true, ["/wifidevices.lp"] = true }, untaint_mt) },
        {"/broadband.lp", "broadband", T"BROADBAND",
         setmetatable({ ["/broadband.lp"] = true }, untaint_mt) },
        {"/wifi.lp?radio=2.4", "wifi", T"WI-FI",
         setmetatable({ ["/wifi.lp"] = true, ["/wifiguest.lp"] = true }, untaint_mt) },
        {"/contentsharing.lp", "contentsharing", T"CONTENT SHARING",
         setmetatable({ ["/contentsharing.lp"] = true }, untaint_mt) },
        {"/tod.lp", "tod", T"PARENTAL CONTROL",
         setmetatable({ ["/tod.lp"] = true }, untaint_mt) }
    }
    if session:hasAccess("/dyndns.lp") then
      items[#items + 1] = {"/dyndns.lp", "dyndns", T"SERVICES",
         setmetatable({ ["/dyndns.lp"] = true, ["/portforwarding.lp"] = true, ["/remoteaccess.lp"] = true, ["/traffic.lp"] = true }, untaint_mt) }
    else
      items[#items + 1] = {"/portforwarding.lp", "portforwarding", T"SERVICES",
         setmetatable({ ["/portforwarding.lp"] = true, ["/remoteaccess.lp"] = true, ["/traffic.lp"] = true }, untaint_mt) }
    end
    items[#items + 1] = {"/user.lp", "admin", T"USER SETTINGS",
         setmetatable({ ["/user.lp"] = true }, untaint_mt)}
    items[#items + 1] = {"/gateway.lp", "gateway", T"ADVANCED", { }}

    local html = {}
    local uri = ngx.var.uri

    for _,v in ipairs(items) do
        local selected = ""
        if v[4][uri] then
            selected = "selected"
        end

        html[#html+1] = format('<div class="menu-item"><a id="%s" href="%s" target="_self"><div class="menu-icon %s %s"></div><div class="menu-text">%s</div></a></div>', v[2], v[1], v[2], selected, v[3])
    end
    ngx.print(html)
  ngx.print('\
        </div>\
    </div>\
</div>\
'); 