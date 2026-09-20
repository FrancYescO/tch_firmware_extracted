#!/bin/sh
# Copyright (c) 2014 Technicolor
# cwmpd integration for firewall3

. $IPKG_INSTROOT/lib/functions.sh

#Ignore /var/state for cwmpd
unset LOAD_STATE
config_load "cwmpd"
LOAD_STATE=1
local state
local interface
local zone
local connectionRequestPort

#check if service is enabled, if not return immediately
config_get state cwmpd_config state 0
if [ $state -eq 0 ]; then
    uci -P /var/state -q delete system.cwmpd
    return 0
fi

config_get interface cwmpd_config interface 'wan'
config_get connectionRequestPort cwmpd_config connectionrequest_port 51007
config_get connectionRequestAllowedIPs cwmpd_config connectionrequest_allowedips "0.0.0.0/0"

zone=$(fw3 -q network "$interface")
zone_lan=$(fw3 -q network "lan")

# Put exception to exclude this service from DMZ rules/port forwarding rules
iptables -t nat -I zone_${zone}_prerouting -p tcp -m tcp --dport $connectionRequestPort -m comment --comment "DMZ_Exception_CWMP_Conn_Reqs" -j ACCEPT

if [ "$zone" == "wan" ]; then
    [ "$(uci -P /var/state -q get system.cwmpd)" == "wan-service" ] ||
        uci_set_state system cwmpd '' wan-service
    uci_set_state system cwmpd proto tcp
    uci_set_state system cwmpd ports "$connectionRequestPort"
else
    uci -P /var/state -q delete system.cwmpd
fi

# Accept connectionRequest messages initiated on this ZONE
iptables -t filter -I zone_${zone}_input -p tcp -m tcp --src $connectionRequestAllowedIPs --dport $connectionRequestPort -m comment --comment "Allow_CWMP_Conn_Reqs" -j ACCEPT
ip6tables -t filter -I zone_${zone}_input -p tcp -m tcp --src $connectionRequestAllowedIPs --dport $connectionRequestPort -m comment --comment "Allow_CWMP_Conn_Reqs" -j ACCEPT

if [ $interface != "lan" ]; then
    iptables -t filter -I zone_${zone_lan}_input -p tcp -m tcp --dport $connectionRequestPort -m comment --comment "Deny_CWMP_Conn_Reqs_from_LAN" -j DROP
    ip6tables -t filter -I zone_${zone_lan}_input -p tcp -m tcp --dport $connectionRequestPort -m comment --comment "Deny_CWMP_Conn_Reqs_from_LAN" -j DROP
fi
