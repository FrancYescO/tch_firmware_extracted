#!/bin/sh
# Copyright (c) 2013 Technicolor

. $IPKG_INSTROOT/lib/functions.sh

TOD_LAN_ZONES=""
chain_timeofday="timeofday_fw"
http_mark=""
mark_match_str=""
accept_rule=""
mask_value=""
mac_filter="/usr/share/transformer/scripts/mac_filter.sh"

setup_routing()
{
    while ip rule delete lookup tod 2>/dev/null; do true; done;
    ip rule add fwmark ${http_mark} lookup tod
    ip route flush table tod
    ip route add local 0.0.0.0/0 dev lo table tod
}

create_tod_chain()
{
    iptables -N ${chain_timeofday} || iptables -F ${chain_timeofday}
    ip6tables -N ${chain_timeofday} || ip6tables -F ${chain_timeofday}

    iptables -t mangle -N ${chain_timeofday} || iptables -t mangle -F ${chain_timeofday}
    ip6tables -t mangle -N ${chain_timeofday} || ip6tables -t mangle -F ${chain_timeofday}

    iptables >/dev/null 2>&1 -t mangle -D PREROUTING -p tcp --dport 80 -m addrtype \! --dst-type LOCAL -j ${chain_timeofday}
    iptables -t mangle -I PREROUTING 1 -p tcp --dport 80 -m addrtype \! --dst-type LOCAL -j ${chain_timeofday}

    ip6tables >/dev/null 2>&1 -t mangle -D PREROUTING -p tcp --dport 80 -m addrtype \! --dst-type LOCAL -j ${chain_timeofday}
    ip6tables -t mangle -I PREROUTING 1 -p tcp --dport 80 -m addrtype \! --dst-type LOCAL -j ${chain_timeofday}
}

create_zone_forward_rule()
{
    local zone="$1"

    iptables -I zone_${zone}_forward -m comment --comment 'Time-of-Day' -j ${chain_timeofday}
    ip6tables -I zone_${zone}_forward -m comment --comment 'Time-of-Day' -j ${chain_timeofday}
}

create_tod_rule_mac_block()
{
    local src_mac="$1"
    local option_time="$2"

    iptables -A ${chain_timeofday} $mark_match_str -m mac --mac-source ${src_mac} ${option_time} -j reject
    [ -n "$http_mark" ] && iptables -t mangle -A ${chain_timeofday} -p tcp --dport 80 -m mac --mac-source ${src_mac} ${option_time} -j TPROXY --tproxy-mark "${http_mark}" --on-port 55556

    ip6tables -A ${chain_timeofday} $mark_match_str -m mac --mac-source ${src_mac} ${option_time} -j reject
    [ -n "$http_mark" ] && ip6tables -t mangle -A ${chain_timeofday} -p tcp --dport 80 -m mac --mac-source ${src_mac} ${option_time} -j TPROXY --tproxy-mark "${http_mark}" --on-port 55556

}

create_tod_rule_mac_allow()
{
    local src_mac="$1"
    local option_time="$2"

    iptables -A ${chain_timeofday} -m mac --mac-source ${src_mac} ${option_time} -j RETURN
    [ -n "$http_mark" ] && iptables -t mangle -A ${chain_timeofday} -m mac --mac-source ${src_mac} ${option_time} -j RETURN
    [ -n "$http_mark" ] && iptables -t mangle -A ${chain_timeofday} -p tcp --dport 80 -m mac --mac-source ${src_mac} -j TPROXY --tproxy-mark "${http_mark}" --on-port 55556
    iptables -A ${chain_timeofday} $mark_match_str -m mac --mac-source ${src_mac} -j reject

    ip6tables -A ${chain_timeofday} -m mac --mac-source ${src_mac} ${option_time} -j RETURN
    [ -n "$http_mark" ] && ip6tables -t mangle -A ${chain_timeofday} -m mac --mac-source ${src_mac} ${option_time} -j RETURN
    [ -n "$http_mark" ] && ip6tables -t mangle -A ${chain_timeofday} -p tcp --dport 80 -m mac --mac-source ${src_mac} -j TPROXY --tproxy-mark "${http_mark}" --on-port 55556
    ip6tables -A ${chain_timeofday} $mark_match_str -m mac --mac-source ${src_mac} -j reject

}

create_tod_rule_mac()
{
    local host="$1"

    local enabled id mode weekdays start_time stop_time
    config_get enabled $host enabled
    config_get id $host id
    config_get mode $host mode
    config_get weekdays $host weekdays
    config_get start_time $host start_time
    config_get stop_time $host stop_time

    id=${id//-/:}

    if [ -z "${enabled}" ] || [ "${enabled}" = "0" ]; then
        echo "Rule is disabled"
        return
    fi

    if [ -z "${id}" ] || [ "${mode}" != "allow" -a "${mode}" != "block" ]; then
      echo "Invalid host config : $1"
      return
    fi

    if [ -n "${weekdays}" -a -n "${start_time}" -a -n "${stop_time}" ]; then
        local str_weekdays=`echo ${weekdays} | tr " " ","`
        local option_time="-m time --kerneltz --weekdays ${str_weekdays} --timestart ${start_time} --timestop ${stop_time}"
        local timedesc="${str_weekdays} ${start_time}-${stop_time}"
    else
        local timedesc="always"
    fi

    if [ "${mode}" = "allow" -a -z "${option_time}" ]; then
        echo "TOD for host [${id}] ignored"
	return
    fi

    echo "Configuring TOD for host [${id}] : ${mode} (${timedesc})"
    create_tod_rule_mac_${mode} "${id}" "${option_time}"
}

tod_host_load() {
    local host="$1"

    local type
    config_get type $host type

    if [ "${type}" = "mac" ]; then
        create_tod_rule_mac ${host}
    fi
}

firewall_zone_check_lan() {
    local zone="$1"

    local name wan
    config_get name $zone name
    [ -n "${name}" ] || return

    config_get_bool wan $zone wan 0
    [ ${wan} -eq 0 ] || return

    create_zone_forward_rule "${name}"
}

load_action() {
    local parental="$(uci -q get parental.general)"

    [ -z "$parental" ] && return   # parental control/weburl module is not enabled in this board

    lanip="$(uci -q get network.lan.ipaddr)"

    # use skipped_mark from weburl
    local skipped_mark="$(uci -q get parental.general.skipped_mark)"
    [ -z "$skipped_mark" ] && skipped_mark="0x1000000"

    local parental_enabled="$(uci -q get parental.general.enable)"
    local tod_enabled="$(uci -q get tod.global.tod_enabled)"

    [ -z "$parental_enabled" ] && parental_enabled="1"
    [ -z "$tod_enabled" ] && tod_enabled="1"

    http_mark="${skipped_mark}/${skipped_mark}"
    mark_match_str="-m connmark ! --mark "$http_mark
    [ "$tod_enabled" = "1" -a "$parental_enabled" = "0" ] && accept_rule="1"
}

if [ -x "$mac_filter" ]; then
	$mac_filter
	exit 0
fi

load_action
setup_routing

create_tod_chain

config_load firewall
config_foreach firewall_zone_check_lan zone

config_load tod
config_get_bool tod_enabled global tod_enabled 1
[ $tod_enabled -eq 0 ] && return

config_foreach tod_host_load host

