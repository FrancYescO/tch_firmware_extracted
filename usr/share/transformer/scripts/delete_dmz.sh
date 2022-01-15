#!/bin/sh

dmz_ip=$(transformer-cli get rpc.network.firewall.dmz.redirect.dest_ip)
value=${dmz_ip#*=}
enabled=$(uci get firewall.dmzredirects.enabled)

if [ ${enabled} == "0" ] && [ -n "$value" ]
then
    conn=$(conntrack -L -g $value | grep ESTABLISHED)
    echo "0" > /proc/sys/net/netfilter/nf_conntrack_tcp_loose && conntrack -D -g $value
    IFS=$'\n'
    for i in $conn; do
        val=$(echo $i | grep -o '\<use[^[:blank:]]*' | cut -d= -f2)
        if [ $val != "1" ]; then
            mark=$(echo $i | grep -o '\<mark[^[:blank:]]*' | cut -d= -f2) && echo "0" > /proc/sys/net/netfilter/nf_conntrack_tcp_loose && conntrack -D -m $mark
        fi
    done
fi
exit 0
