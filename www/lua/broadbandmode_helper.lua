return {
    {
        name = "adsl",
        default = false,
        description = "ADSL2+",
        view = "broadband-adsl-advanced.lp",
        card = "002_broadband_xdsl.lp",
        check = {
            { "uci.network.interface.@wan.ifname", "^atm0$"},
        },
        operations = {
            { "uci.network.interface.@wan.ifname", "atm0"},
            { "uci.wansensing.global.l2type", "ADSL" },
        },
    },
    {
        name = "vdsl",
        default = true,
        description = "VDSL2",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = {
            { "uci.network.interface.@wan.ifname", "^ptm0"},
        },
        operations = {
            { "uci.network.interface.@wan.ifname", "ptm0"},
            { "uci.wansensing.global.l2type", "VDSL" },
        },
    },
    {
        name = "ethernet",
        default = false,
        description = "Ethernet",
        view = "broadband-ethernet.lp",
        card = "002_broadband_ethernet.lp",
        check = {
            { "uci.network.interface.@wan.ifname", "^eth4"},
        },
        operations = {
            { "uci.network.interface.@wan.ifname", "eth4"},
            { "uci.wansensing.global.l2type", "ETH" },
        },
    },
}
