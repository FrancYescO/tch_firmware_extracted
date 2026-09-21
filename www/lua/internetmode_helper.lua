return {
    {
        name = "bridge",
        default = false,
        description = "Bridge Mode",
        view = "internet-bridged.lp",
        card = "003_internet_bridged.lp",
	check = {
            { "uci.network.interface.@wan.proto", "^bridge$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "bridge"},
        },
    },
    {
        name = "dhcp",
        default = false,
        description = "DHCP Routed Mode",
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
        name = "static",
        default = true,
        description = "Static Routed Mode",
        view = "internet-static-routed.lp",
        card = "003_internet_static_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^static$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "static"},
        },
    },
    {
        name = "pppoe",
        default = false,
        description = "PPPoE Routed Mode",
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
        name = "pppoa",
        default = false,
        description = "PPPoA Routed Mode",
        view = "internet-pppoe-routed.lp",
        card = "003_internet_pppoe_routed.lp",
	check = {
            { "uci.network.interface.@wan.proto", "^pppoa$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "pppoa"},
        },
    },
}
