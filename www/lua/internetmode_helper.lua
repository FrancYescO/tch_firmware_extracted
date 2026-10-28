return {
    {
        name = "dhcp",
        default = true,
        description = "DHCP routed mode",
        view = "internet-dhcp-routed.lp",
        card = "003_internet_dhcp_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^dhcp$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "dhcp"},
			{ "uci.xtm.atmdevice.@atm_8_35.enc", "llc"},
			{ "uci.xtm.atmdevice.@atm_8_35.ulp", "eth"},
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
			{ "uci.xtm.atmdevice.@atm_8_35.enc", "llc"},
			{ "uci.xtm.atmdevice.@atm_8_35.ulp", "eth"},
        },
    },
    {
        name = "pppoa",
        default = false,
        description = "PPPoA routed mode",
        view = "internet-pppoa-routed.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^pppoa$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "pppoa"},
			{ "uci.xtm.atmdevice.@atm_8_35.enc", "vcmux"},
			{ "uci.xtm.atmdevice.@atm_8_35.ulp", "ppp"},
        },
    },
    {
        name = "static",
        default = false,
        description = "Fixed IP mode",
        view = "internet-static-routed.lp",
        card = "003_internet_static_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^static$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "static"},
			{ "uci.xtm.atmdevice.@atm_8_35.enc", "llc"},
			{ "uci.xtm.atmdevice.@atm_8_35.ulp", "eth"},
        },
    },
}
