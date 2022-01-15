#!/bin/sh

dmz_ip=$(transformer-cli get rpc.network.firewall.dmz.redirect.dest_ip)
value=${dmz_ip#*=}
enabled=$(uci get firewall.dmzredirects.enabled)
if [ ${enabled} == "0" ] && [ -n "$value" ]
then
    echo "0" > /proc/sys/net/netfilter/nf_conntrack_tcp_loose && conntrack -D -g $value
fi
exit 0
