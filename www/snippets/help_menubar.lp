--pretranslated: do not change this file
 ngx.print('<div class="container" style="width:830px">\
    <div class="row">\
        <div class="menubar">\
\
');  
    gettext.textdomain('webui-telstra')

    local format = string.format
    local untaint_mt = require("web.taint").untaint_mt
    local setmetatable = setmetatable
    local items = {
        {"/helpfiles/help_home.lp", "home", T"HOME",
         setmetatable({ ["/helpfiles/help_home.lp"] = true }, untaint_mt) },
        {"/helpfiles/help_broadband.lp", "broadband", T"BROADBAND",
         setmetatable({ ["/helpfiles/help_broadband.lp"] = true }, untaint_mt) },
        {"/helpfiles/help_wifi.lp", "wifi", T"WI-FI",
         setmetatable({ ["/helpfiles/help_wifi.lp"] = true, ["/helpfiles/help_wifiguest.lp"] = true }, untaint_mt) },
        {"/helpfiles/help_contentsharing.lp", "contentsharing", T"CONTENT SHARING",
         setmetatable({ ["/helpfiles/help_contentsharing.lp"] = true }, untaint_mt) },
        {"/helpfiles/help_tod.lp", "tod", T"PARENTAL CONTROL",
         setmetatable({ ["/helpfiles/help_tod.lp"] = true }, untaint_mt) },
        {"/helpfiles/help_services.lp", "dyndns", T"SERVICES",
         setmetatable({ ["/helpfiles/help_services.lp"] = true, ["/helpfiles/help_dyndns.lp"] = true, ["/helpfiles/help_portforwarding.lp"] = true, ["/helpfiles/help_remoteaccess.lp"] = true, ["/helpfiles/help_traffic.lp"] = true }, untaint_mt) },
        {"/helpfiles/help_usersetting.lp", "admin", T"USER SETTINGS",
         setmetatable({ ["/helpfiles/help_usersetting.lp"] = true }, untaint_mt) },
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