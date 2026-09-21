#!/bin/sh
# Copyright (c) 2013 Technicolor

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh

fullcone_flush_zone_chain() {
    local zone=$1
    local chain="fullcone_${zone}"
    iptables -t nat -F ${chain}
}

fullcone_load() {
    local cfg="$1"
    local src
    local src_ip src_port
    local dest_ip dest_port
    local src_dip

    config_get src $cfg src
    config_get src_ip $cfg src_ip
    config_get src_port $cfg src_port
    config_get dest_ip $cfg dest_ip
    config_get dest_port $cfg dest_port
    config_get src_dip $cfg src_dip

    local params="-p udp"
    local action="-j MASQUERADE --mode fullcone"
    [ -n "$src_ip"    ] && params="${params} -s $src_ip"
    [ -n "$src_port"  ] && params="${params} --sport $src_port"
    [ -n "$dest_ip"   ] && params="${params} -d $dest_ip"
    [ -n "$dest_port" ] && params="${params} --dport $dest_port"
    [ -n "$src_dip" ] && action="-j SNAT --to $src_dip --mode fullcone"

    iptables -t nat -A fullcone_${src:-wan} ${params} ${action}
}

firewall_zone_check() {
    local zone="$1"

    local name wan
    config_get name $zone name
    [ -n "${name}" ] || return

    config_get_bool wan $zone wan 0
    if [ ${wan} -eq 1 ]; then
      fullcone_flush_zone_chain "${name}"
    fi
}

config_load firewall
config_foreach firewall_zone_check zone

config_foreach fullcone_load cone
iptables -D OUTPUT -m conntrack --ctstate INVALID -m comment --comment "!fw3" -j DROP 2>/dev/null
ip6tables -D OUTPUT -m conntrack --ctstate INVALID -m comment --comment "!fw3" -j DROP 2>/dev/null

