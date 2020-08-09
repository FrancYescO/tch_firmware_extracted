return {
    {
        name = "dhcp",
        default = false,
        description = "DHCP routed mode",
        view = "internet-dhcp-routed.lp",
        card = "003_internet_dhcp_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^dhcp$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "dhcp"},
        },
    },
    {
        name = "pppoe",
        default = false,
        description = "PPPoE routed mode",
        view = "internet-pppoe-routed.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^pppoe$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "pppoe"},
        },
    },
    {
        name = "default",
        default = true,
        description = "Trying to connect ...",
        view = "internet-default.lp",
        card = "003_internet_default.lp",
        check = {
            { "uci.network.interface.@wan.proto", "fake"}, -- will be triggered as default if other fail
        },
        operations = {
            { "uci.network.interface.@wan.proto", "pppoe"},
        },
    },
    {
        name = "static",
        default = false,
        description = "Static routed mode",
        view = "internet-static-routed.lp",
        card = "003_internet_static_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^static$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "static"},
        },
    },
}
