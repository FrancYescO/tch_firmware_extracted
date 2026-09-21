local content_helper = require("web.content_helper")
local format = string.format
local wan = {
    iface = "uci.network.interface.@wan.ifname",
    port = "uci.network.interface.@wan.device",
}
content_helper.getExactContent(wan)

local stats
-- Here we just try to remove the potential vlan id from the interface name.
local iface = string.match(wan.iface, "([^%.]+)")
local port = string.match(wan.port, "([^%.]+)")
local ifpath = "uci.network.interface.@wan.ifname"
if iface == "pppoe-wan" then
   ifpath = "rpc.network.interface.@wan.ppp.ll_intf"
end

return {
    {
        name = "adsl",
        default = false,
        description = "ADSL",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = {
            { ifpath, "atm0"},
        },
        operations = {
            { "uci.network.interface.@wan.ifname", format("^atm0$")},
        },
    },
    {
        name = "vdsl",
        default = true,
        description = "VDSL2",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = {
            { ifpath, "^ptm0$"},
        },
        operations = {
            { "uci.network.interface.@wan.ifname", format("^ptm0$")},
        },
    },
    {
        name = "ethernet",
        default = false,
        description = "Ethernet",
        view = "broadband-ethernet.lp",
        card = "002_broadband_ethernet.lp",
        check = {
            { ifpath, "^eth4$"},
        },
        operations = {
            { "uci.network.interface.@wan.ifname", format("eth4")},
        },
    },
}
