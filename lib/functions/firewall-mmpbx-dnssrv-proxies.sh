#!/bin/sh
# MMPBX: accept DNSSRV proxies
# $1 = 1, add firewall rules for the proxies
#      0, delete rules

if [ $# -eq 0 ]; then
    # missing the action parameter
    return
fi

valid_ip(){
    local  ip=$1

    if echo "$ip" | { IFS=. read a b c d;
        test "$a" -ge 0 -a "$a" -le 255 \
        -a "$b" -ge 0 -a "$b" -le 255 \
        -a "$c" -ge 0 -a "$c" -le 255 \
        -a "$d" -ge 0 -a "$d" -le 255 \
        2> /dev/null; }; then
        return 0
    else
        return 1
    fi
}

create_dnssrv_chain(){
    var=`iptables -L MMPBX_DNSSRV` 2> /dev/null
    [ -n "$var" ] && return;

    iptables -N MMPBX_DNSSRV
    iptables -I MMPBX -j MMPBX_DNSSRV
}

delete_dnssrv_chain(){
    var=`iptables -L MMPBX_DNSSRV` 2> /dev/null
    [ -z "$var" ] && return;

    iptables -D MMPBX -j MMPBX_DNSSRV
    iptables -F MMPBX_DNSSRV
    iptables -X MMPBX_DNSSRV
}

if [ $1 -eq 0 ]; then
    delete_dnssrv_chain
    return
fi

if [ $1 -eq 1 ]; then
    create_dnssrv_chain

    proxyport=`uci get mmpbxrvsipnet.sip_net.primary_proxy_port`
    if [ $proxyport -gt 0 ]; then
        return;
    fi

    srv_domain=`uci get mmpbxrvsipnet.sip_net.primary_proxy`
    if valid_ip $srv_domain; then
        return;
    fi

    dnsget -t naptr $srv_domain | sed -e 's/^.* \([^ ]*\)$/\1/'| while read ptr_record; do
        dnsget -t srv $ptr_record | sed -e 's/^.* \([^ ]*\)$/\1/'| while read srv_record; do
            nslookup $srv_record  |grep Address |grep -v "#53" |grep -v "0.0.0.0" | cut -d ':' -f 2 | while read address; do
                iptables -t filter -I MMPBX_DNSSRV --src $address -p udp --dport $proxyport -m comment --comment "Accept DNSSRV proxy address" -j ACCEPT
                iptables -t filter -I MMPBX_DNSSRV --src $address -p tcp --dport $proxyport -m comment --comment "Accept DNSSRV proxy address" -j ACCEPT
            done
        done
    done
fi