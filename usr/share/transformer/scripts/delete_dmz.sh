#!/bin/sh

dmz_mac=$(uci get firewall.dmzredirect.dest_mac)
value=$(cat /var/dhcp.leases|grep $dmz_mac|grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
enabled=$(uci get firewall.dmzredirects.enabled)
if [ ${enabled} == "0" ] && [ -n "$value" ]
then
    echo "0" > /proc/sys/net/netfilter/nf_conntrack_tcp_loose && conntrack -D -g $value
fi
exit 0
