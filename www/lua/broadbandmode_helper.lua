return {
    {
        name = "adsl",
        default = false,
        description = "ADSL2+",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = {
            { "uci.network.interface.@wan.ifname", "^atm_wan$"},
        },
        operations = {
            { "uci.network.interface.@wan.ifname", "atm_wan"},
        },
    },
    {
        name = "vdsl",
        default = true,
        description = "VDSL",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = {
            { "uci.network.interface.@wan.ifname", "^ptm0$"},
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
            { "uci.network.interface.@wan.ifname", "^eth4$"},
        },
        operations = {
            { "uci.network.interface.@wan.ifname", "eth4"},
        },
    },
    {
        name = "bridge",
        default = false,
        description = "Bridge",
        view = "broadband-bridge.lp",
        card = "002_broadband_bridge.lp",
        check = {
            { "uci.network.interface.@wan.ifname", "[^%s]+%s+[^%s]+"},
        },
        operations = function()
            local message_helper = require("web.uimessage_helper")
            message_helper.pushMessage(T"Switch to bridge mode is not allowed here, please go to \"WAN services\" card.", "info")
        end
    },
}
