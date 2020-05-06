local proxy = require("datamodel")
local format = string.format 
local if_name = proxy.get("uci.env.custovar.wan_if")[1].value
return {
    {
        name = "adsl",
        default = false,
        description = "ADSL2+",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = {
            { format("uci.network.interface.@%s.ifname",if_name), "^atm0$"},
        },
        operations = {
            { format("uci.network.interface.@%s.ifname",if_name), "atm0"},
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
            { format("uci.network.interface.@%s.ifname",if_name), "^ptm0"},
        },
        operations = {
            { format("uci.network.interface.@%s.ifname",if_name), "ptm0"},
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
            { format("uci.network.interface.@%s.ifname",if_name), "^eth4"},
        },
        operations = {
            { format("uci.network.interface.@%s.ifname",if_name), "eth4"},
            { "uci.wansensing.global.l2type", "ETH" },
        },
    },
}
