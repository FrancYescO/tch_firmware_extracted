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
    local items = {
        {"/home.lp", "home", T"HOME",
         setmetatable({ ["/home.lp"] = true }, untaint_mt) },
        {"/broadband.lp", "broadband", T"BROADBAND",
         setmetatable({ ["/broadband.lp"] = true }, untaint_mt) },
        {"/wifi.lp?radio=2.4", "wifi", T"WI-FI",
         setmetatable({ ["/wifi.lp"] = true, ["/wifiguest.lp"] = true }, untaint_mt) },
        {"/contentsharing.lp", "contentsharing", T"CONTENT SHARING",
         setmetatable({ ["/contentsharing.lp"] = true }, untaint_mt) },
        {"/tod.lp", "tod", T"PARENTAL CONTROL",
         setmetatable({ ["/tod.lp"] = true }, untaint_mt) },
        {"/dyndns.lp", "dyndns", T"SERVICES",
         setmetatable({ ["/dyndns.lp"] = true, ["/portforwarding.lp"] = true, ["/remoteaccess.lp"] = true, ["/traffic.lp"] = true }, untaint_mt) },
        {"/user.lp", "admin", T"USER SETTINGS",
         setmetatable({ ["/user.lp"] = true }, untaint_mt)},
        {"/gateway.lp", "gateway", T"ADVANCED", { }}
    }
    local html = {}
    local uri = ngx.var.uri

    for _,v in ipairs(items) do
        local selected = ""
        if v[4][uri] then
            selected = "selected"
        end

        html[#html+1] = format('<div class="menu-item"><a href="%s" target="_self"><div class="menu-icon %s %s"></div><div class="menu-text">%s</div></a></div>', v[1], v[2], selected, v[3])
    end
    ngx.print(html)
  ngx.print('\
        </div>\
    </div>\
</div>\
'); 