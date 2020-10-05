#!/bin/sh
# Copyright (c) 2015 Technicolor
# telnet integration for firewall3

. $IPKG_INSTROOT/lib/functions.sh

WAN_PORTS=

parse_telnet_setup() {
    local section="$1"
    local enable interface zone port allowedclientips iprange allowedip allowedipv6

    config_get_bool enable "${section}" enable 1
    [ "${enable}" -eq 0 ] && return 0

    config_get interface "$section" Interface
    [ -z "$interface" ] && return 0 # do nothing if interface is not specified
    zone=$(fw3 -q network "$interface")
    [ -z "$zone" ] && return 0 # unknown zone for this interface
    config_get port "${section}" Port 23
    config_get allowedclientips "$section" AllowedClientIPs

    # Put exception to exclude this service from DMZ rules/port forwarding rules
    iptables -t nat -I zone_${zone}_prerouting -p tcp -m tcp --dport $port -m comment --comment "DMZ_Exception_Telnet" -j ACCEPT

    [ "$zone" == "wan" ] && append WAN_PORTS $port

    # Accept connections initiated from allowed client IPs
    for iprange in $allowedclientips ; do
        if [ "${iprange/:/}" == "$iprange" ]; then
            iptables -t filter -I zone_${zone}_input -p tcp -m tcp --src $iprange --dport $port -m comment --comment "Allow_Telnet_Conn" -j ACCEPT
	    allowedip=$(( allowedip + 1 ))
        else
            ip6tables -t filter -I zone_${zone}_input -p tcp -m tcp --src $iprange --dport $port -m comment --comment "Allow_Telnet_Conn" -j ACCEPT
            allowedipv6=$(( allowedipv6 + 1 ))
        fi
    done
    allowedip=$(( allowedip + 1 ))
    iptables -t filter -I zone_${zone}_input $allowedip -p tcp -m tcp  --dport 23 -m comment --comment "Allow_Telnet_Conn" -j DROP
    allowedipv6=$(( allowedipv6 + 1 ))
    ip6tables -t filter -I zone_${zone}_input $allowedipv6 -p tcp -m tcp  --dport 23 -m comment --comment "Allow_Telnet_Conn" -j DROP
}

config_load "telnet"
config_foreach parse_telnet_setup telnet
