return {
    {
        name = "dhcp",
        default = true,
        description = "IPoE routed mode",
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
}
