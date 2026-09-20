<div class="container" style="width:830px">
    <div class="row">
        <div class="menubar">

<%
    gettext.textdomain('webui-telstra')

    local ipairs, string = ipairs, string
    local items = {
        {"/helpfiles/help_home.lp", "home", T"HOME", { ["/helpfiles/help_home.lp"] = true }},
        {"/helpfiles/help_broadband.lp", "broadband", T"BROADBAND", { ["/helpfiles/help_broadband.lp"] = true }},
        {"/helpfiles/help_wifi.lp", "wifi", T"WI-FI", { ["/helpfiles/help_wifi.lp"] = true, ["/helpfiles/help_wifiguest.lp"] = true }},
        {"/helpfiles/help_contentsharing.lp", "contentsharing", T"CONTENT SHARING", { ["/helpfiles/help_contentsharing.lp"] = true }},
        {"/helpfiles/help_tod.lp", "tod", T"PARENTAL CONTROL", { ["/helpfiles/help_tod.lp"] = true }},
        {"/helpfiles/help_services.lp", "dyndns", T"SERVICES", { ["/helpfiles/help_services.lp"] = true, ["/helpfiles/help_dyndns.lp"] = true, ["/helpfiles/help_portforwarding.lp"] = true, ["/helpfiles/help_remoteaccess.lp"] = true, ["/helpfiles/help_traffic.lp"] = true }},
        {"/helpfiles/help_usersetting.lp", "admin", T"USER SETTINGS", { ["/helpfiles/help_usersetting.lp"] = true }},
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
