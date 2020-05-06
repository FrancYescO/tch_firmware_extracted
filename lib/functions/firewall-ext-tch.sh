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

helper_load() {
    local cfg="$1"
    local enable
    local helper proto intf
    local src_ip src_port 
    local dest_ip dest_port
    local pr
    local family

    config_get_bool enable $cfg enable '1'
    [ "$enable" -eq 0 ] && return
    config_get helper $cfg helper
    [ -n "$helper" ] || return 1
    config_get proto $cfg proto "tcpudp"
    [ -n "$proto" ] || return 1
    [ "$proto" = "tcpudp" ] && proto="tcp udp"

    config_get family $cfg family "any"
    [ "$family" = "any" ] && family="ipv4 ipv6"

    config_get intf $cfg intf
    if [ -n "$intf" ]; then
        network_get_device intf $intf || return 1
    fi
    config_get src_ip $cfg src_ip
    config_get src_port $cfg src_port
    config_get dest_ip $cfg dest_ip
    config_get dest_port $cfg dest_port

    local params=""
    [ -n "$intf"   ] && params="${params} -i $intf"
    [ -n "$src_ip"    ] && params="${params} -s $src_ip"
    [ -n "$src_port"  ] && params="${params} --sport $src_port"
    [ -n "$dest_ip"   ] && params="${params} -d $dest_ip"
    [ -n "$dest_port" ] && params="${params} --dport $dest_port"

    for fm in ${family}; do
        local cmd
        case "$fm" in
            "ipv4")
                cmd=iptables
                ;;
            "ipv6")
                cmd=ip6tables
                ;;
            *)
                cmd=true
                ;;
        esac
        for pr in ${proto}; do
            ${cmd} -t raw -A helper_binds -p "${pr}" ${params} -j CT \
                   --helper "${helper}" || \
                            logger -t fw-ext -p daemon.error \
                                     "Error adding CT helper $helper for $pr (${params})"
        done
    done
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

iptables -t raw -F helper_binds
ip6tables -t raw -F helper_binds
config_foreach helper_load helper

