#!/bin/sh
# Copyright (c) 2013 Technicolor

. $IPKG_INSTROOT/lib/functions.sh

TOD_LAN_ZONES=""
chain_timeofday="timeofday_fw"
timeofday_rule_index=0
http_mark=""
http_accept_mark=""
mark_match_str=""
accept_rule=""
mask_value=""

create_tod_chain()
{
    iptables -N ${chain_timeofday} || iptables -F ${chain_timeofday}

    ip6tables -N ${chain_timeofday} || ip6tables -F ${chain_timeofday}
}

create_zone_forward_rule()
{
    local zone="$1"

    [ "$accept_rule" = "1" ] && iptables -I zone_${zone}_forward -p tcp --dport 80 -m connmark --mark 0x0000000/0x${mask_value} -m comment --comment 'tod_accept_unblocked_http' -j CONNMARK --set-xmark $http_accept_mark
    iptables -I zone_${zone}_forward -m comment --comment 'Time-of-Day' -j ${chain_timeofday}

    [ "$accept_rule" = "1" ] && ip6tables -I zone_${zone}_forward -p tcp --dport 80 -m connmark --mark 0x0000000/0x${mask_value} -m comment --comment 'tod_accept_unblocked_http' -j CONNMARK --set-xmark $http_accept_mark
    ip6tables -I zone_${zone}_forward -m comment --comment 'Time-of-Day' -j ${chain_timeofday}
}

create_tod_rule_mac_block()
{
    local src_mac="$1"
    local option_time="$2"
    local index="$3"

    iptables -I ${chain_timeofday} ${index} $mark_match_str -m mac --mac-source ${src_mac} ${option_time} -j reject
    [ -n "$http_mark" ] && iptables -I ${chain_timeofday} ${index} -p tcp --dport 80 -m mac --mac-source ${src_mac} ${option_time} -j CONNMARK --set-xmark $http_mark

    ip6tables -I ${chain_timeofday} ${index} $mark_match_str -m mac --mac-source ${src_mac} ${option_time} -j reject
    [ -n "$http_mark" ] && ip6tables -I ${chain_timeofday} ${index} -p tcp --dport 80 -m mac --mac-source ${src_mac} ${option_time} -j CONNMARK --set-xmark $http_mark
}

check_append_rule()
{
    local rule=$1
    local ipt=$2

    [ -z "$rule" ] && return

    ip${ipt}tables -C $rule
    if [ "$?" = "1" ]; then
         ip${ipt}tables -A $rule
    fi
}

create_tod_rule_mac_allow()
{
    local src_mac="$1"
    local option_time="$2"
    local index="$3"

    iptables -I ${chain_timeofday} ${index} -m mac --mac-source ${src_mac} ${option_time} -j RETURN

    [ -n "$http_mark" ] && check_append_rule "${chain_timeofday} -p tcp --dport 80 -m mac --mac-source ${src_mac} -j CONNMARK --set-xmark $http_mark"
    check_append_rule "${chain_timeofday} $mark_match_str -m mac --mac-source ${src_mac} -j reject"

    ip6tables -I ${chain_timeofday} ${index} -m mac --mac-source ${src_mac} ${option_time} -j RETURN

    [ -n "$http_mark" ] && check_append_rule "${chain_timeofday} -p tcp --dport 80 -m mac --mac-source ${src_mac} -j CONNMARK --set-xmark $http_mark" 6
    check_append_rule "${chain_timeofday} $mark_match_str -m mac --mac-source ${src_mac} -j reject" 6
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

    timeofday_rule_index=$(($timeofday_rule_index+1))

    echo "Configuring TOD for host [${id}] : ${mode} (${timedesc})"
    create_tod_rule_mac_${mode} "${id}" "${option_time}" "$timeofday_rule_index"
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

    local redir_mark="$(uci -q get parental.general.redirect_mark_value)"
    local accept_mark="$(uci -q get parental.general.accept_mark_value)"
    mask_value="$(uci -q get parental.general.mark_mask_value)"
    local parental_enabled="$(uci -q get parental.general.enable)"
    local tod_enabled="$(uci -q get tod.global.tod_enabled)"

    [ -z "$redir_mark" ] && redir_mark="4000000"
    [ -z "$accept_mark" ] && accept_mark="2000000"
    [ -z "$mask_value" ] && mask_value="6000000"
    [ -z "$parental_enabled" ] && parental_enabled="1"
    [ -z "$tod_enabled" ] && tod_enabled="1"

    http_mark="0x${redir_mark}/0x${mask_value}"
    http_accept_mark="0x${accept_mark}/0x${mask_value}"
    mark_match_str="-m connmark ! --mark "$http_mark
    [ "$tod_enabled" = "1" -a "$parental_enabled" = "0" ] && accept_rule="1"
}


load_action

create_tod_chain

config_load firewall
config_foreach firewall_zone_check_lan zone

config_load tod
config_get_bool tod_enabled global tod_enabled 1
[ $tod_enabled -eq 0 ] && return

config_foreach tod_host_load host

