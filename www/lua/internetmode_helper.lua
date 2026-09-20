local session = ngx.ctx.session
local intfSelected = session:retrieve("postedIntf_internet_modal") or "wan"
local path = string.format("uci.network.interface.@%s.proto", intfSelected)
return {
    {
        name = "dhcp",
        default = true,
        description = "DHCP routed mode",
        view = "internet-dhcp-routed.lp",
        card = "003_internet_dhcp_routed.lp",
        check = {
            { path, "^dhcp$"},
        },
        operations = {
            { path, "dhcp"},
        },
    },
    {
        name = "pppoe",
        default = false,
        description = "PPPoE routed mode",
        view = "internet-pppoe-routed.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            { path, "^pppoe$"},
        },
        operations = {
            { path, "pppoe"},
        },
    },
    {
        name = "pppoa",
        default = false,
        description = "PPPoA routed mode",
        view = "internet-pppoa-routed.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            { path, "^pppoa$"},
        },
        operations = {
            { path, "pppoa"},
        },
    },
    {
        name = "static",
        default = false,
        description = "Fixed IP mode",
        view = "internet-static-routed.lp",
        card = "003_internet_static_routed.lp",
        check = {
            { path, "^static$"},
        },
        operations = {
            { path, "static"},
        },
    },
}
