#!/bin/sh
# Copyright (c) 2014 Technicolor
# cwmpd integration for firewall3

. $IPKG_INSTROOT/lib/functions.sh

config_load "cwmpd"
local state
local interface
local zone
local connectionRequestPort

#check if service is enabled, if not return immediately
config_get state cwmpd_config state 0
[ $state -eq 0 ] && return 0

config_get interface cwmpd_config interface 'wan'
config_get connectionRequestPort cwmpd_config connectionrequest_port 51007

zone=$(fw3 -q network "$interface")
zone_lan=$(fw3 -q network "lan")

# Put exception to exclude this service from DMZ rules/port forwarding rules
iptables -t nat -I zone_${zone}_prerouting -p tcp -m tcp --dport $connectionRequestPort -m comment --comment "DMZ_Exception_CWMP_Conn_Reqs" -j ACCEPT

# Accept connectionRequest messages initiated on this ZONE
iptables -t filter -I zone_${zone}_input -p tcp -m tcp --dport $connectionRequestPort -m comment --comment "Allow_CWMP_Conn_Reqs" -j ACCEPT
ip6tables -t filter -I zone_${zone}_input -p tcp -m tcp --dport $connectionRequestPort -m comment --comment "Allow_CWMP_Conn_Reqs" -j ACCEPT

if [ $interface != "lan" ]; then
	iptables -t filter -I zone_${zone_lan}_input -p tcp -m tcp --dport $connectionRequestPort -m comment --comment "Deny_CWMP_Conn_Reqs_from_LAN" -j DROP
	ip6tables -t filter -I zone_${zone_lan}_input -p tcp -m tcp --dport $connectionRequestPort -m comment --comment "Deny_CWMP_Conn_Reqs_from_LAN" -j DROP
fi

