return {
    {
        name = "adsl",
        default = false,
        description = "ADSL2+",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = {
            { "uci.network.interface.@wan.ifname", "^atm_8_35$"},
        },
        operations = {
            { "uci.network.interface.@wan.ifname", "atm_8_35"},
        },
    },
    {
        name = "vdsl",
        default = true,
        description = "VDSL",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = {
            { "uci.network.interface.@wan.ifname", "^ptm0"},
        },
        operations = {
            { "uci.network.interface.@wan.ifname", "ptm0"},
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
        },
    },
}
