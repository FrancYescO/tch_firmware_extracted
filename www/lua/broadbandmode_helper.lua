return {
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
