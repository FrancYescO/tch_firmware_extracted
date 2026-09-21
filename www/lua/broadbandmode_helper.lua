return {
    {
        name = "adsl",
        default = true,
        description = "ADSL broadband",
        view = "broadband-adsl-advanced.lp",
        card = "002_broadband_xdsl.lp",
        check = {
            { "uci.network.interface.@wan.ifname", "^atm_8_36$"},
        },
        operations = {
        },
    },
}