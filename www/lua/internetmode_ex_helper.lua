return {
    {
        name = "dhcpv6",
        default = true,
        description = "DHCPv6",
        view = "internet-dhcpv6.lp",
        check = {
            {"uci.network.interface.@wan6.proto", "^dhcpv6$"},
        },
        operations = {
            {"uci.network.interface.@wan6.proto", "dhcpv6"},
            {"uci.network.interface.@wan6.ip6prefix", ""},
            {"uci.network.interface.@wan6.ip6prefixlen", ""},
            {"uci.network.interface.@wan6.ip4prefixlen", ""},
            {"uci.network.interface.@wan6.peeraddr", ""},
        },
    },
    {
        name = "6rd",
        default = false,
        description = "6rd",
        view = "internet-6rd.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            {"uci.network.interface.@wan6.proto", "^6rd$"},
        },
        operations = {
            {"uci.network.interface.@wan6.proto", "6rd"},
        },
    },
}
