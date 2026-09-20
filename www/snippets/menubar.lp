<div class="container">
    <div class="row">
        <div class="menubar">

<%
    gettext.textdomain('webui-telstra')

    local ipairs, string = ipairs, string
    local items = {
        {"/home.lp", "home", T"HOME", { ["/home.lp"] = true }},
        {"/broadband.lp", "broadband", T"BROADBAND", { ["/broadband.lp"] = true }},
        {"/wifi.lp?radio=2.4", "wifi", T"WI-FI", { ["/wifi.lp"] = true, ["/wifiguest.lp"] = true }},
        {"/contentsharing.lp", "contentsharing", T"CONTENT SHARING", { ["/contentsharing.lp"] = true }},
        {"/tod.lp", "tod", T"PARENTAL CONTROL", { ["/tod.lp"] = true }},
        {"/dyndns.lp", "dyndns", T"SERVICES", { ["/dyndns.lp"] = true, ["/portforwarding.lp"] = true, ["/remoteaccess.lp"] = true, ["/traffic.lp"] = true }},
        {"/user.lp", "admin", T"USER SETTINGS", { ["/user.lp"] = true }},
        {"/gateway.lp", "gateway", T"ADVANCED", { }}
    }
    local html = {}

    for _,v in ipairs(items) do
        local selected = ""
        if v[4][ngx.var.uri] then
            selected = "selected"
        end

        html[#html+1] = string.format('<div class="menu-item"><a href="%s" target="_self"><div class="menu-icon %s %s"></div><div class="menu-text">%s</div></a></div>', v[1], v[2], selected, v[3])
    end
    ngx.print(html)
%>
        </div>
    </div>
</div>
