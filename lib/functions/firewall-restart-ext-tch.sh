#!/bin/sh
# Copyright (c) 2015 Technicolor

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh

fullcone_create_zone_chain() {
    local zone=$1
    local chain="fullcone_${zone}"
    iptables -t nat -N ${chain}
    iptables -t nat -I postrouting_${zone}_rule -m comment --comment "Fullcone" -j ${chain}
}

firewall_zone_check() {
    local zone="$1"

    local name wan
    config_get name $zone name
    [ -n "${name}" ] || return

    config_get_bool wan $zone wan 0
    if [ ${wan} -eq 1 ]; then
      fullcone_create_zone_chain "${name}"
    fi
}

iptables -t raw -N helper_binds
iptables -t raw -A PREROUTING -j helper_binds
ip6tables -t raw -N helper_binds
ip6tables -t raw -A PREROUTING -j helper_binds

config_load firewall
config_foreach firewall_zone_check zone

