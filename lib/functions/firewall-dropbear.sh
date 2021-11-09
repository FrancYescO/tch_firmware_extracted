#!/bin/sh
# Copyright (c) 2015 Technicolor
# dropbear integration for firewall3

. $IPKG_INSTROOT/lib/functions.sh

WAN_PORTS=

parse_dropbear_setup() {
    local section="$1"
    local enable interface zone port allowedclientips iprange

    config_get_bool enable "${section}" enable 1
    [ "${enable}" -eq 0 ] && return 0

    config_get interface "$section" Interface
    [ -z "$interface" ] && return 0 # do nothing if interface is not specified
    zone=$(fw3 -q network "$interface")
    [ -z "$zone" ] && return 0 # unknown zone for this interface

    config_get port "${section}" Port 22
    config_get allowedclientips "$section" AllowedClientIPs

    # Put exception to exclude this service from DMZ rules/port forwarding rules
    iptables -t nat -I zone_${zone}_prerouting -p tcp -m tcp --dport $port -m comment --comment "DMZ_Exception_Dropbear" -j ACCEPT

    [ "$zone" == "wan" ] && append WAN_PORTS $port

    # Accept connections initiated from allowed client IPs
    for iprange in $allowedclientips ; do
        if [ "${iprange/:/}" == "$iprange" ]; then
            iptables -t filter -I zone_${zone}_input -p tcp -m tcp --src $iprange --dport $port -m comment --comment "Allow_Dropbear_Conn" -j ACCEPT
        else
            ip6tables -t filter -I zone_${zone}_input -p tcp -m tcp --src $iprange --dport $port -m comment --comment "Allow_Dropbear_Conn" -j ACCEPT
        fi
    done
}

config_load "dropbear"
config_foreach parse_dropbear_setup dropbear

if [ -n "$WAN_PORTS" ]; then
    [ "$(uci -P /var/state -q get system.dropbear)" == "wan-service" ] ||
        uci_set_state system dropbear '' wan-service
    uci_set_state system dropbear proto tcp
    uci_set_state system dropbear ports "$WAN_PORTS"
else
    uci -P /var/state -q delete system.dropbear || true
fi
