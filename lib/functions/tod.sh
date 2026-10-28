#!/bin/sh
# Copyright (c) 2013 Technicolor

. $IPKG_INSTROOT/lib/functions.sh

TOD_LAN_ZONES=""
chain_timeofday="timeofday_fw"
timeofday_rule_index=0

create_tod_chain()
{
    iptables -N ${chain_timeofday} || iptables -F ${chain_timeofday}

    ip6tables -N ${chain_timeofday} || ip6tables -F ${chain_timeofday}
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
    local index="$3"

    iptables -I ${chain_timeofday} ${index} -m mac --mac-source ${src_mac} ${option_time} -j reject

    ip6tables -I ${chain_timeofday} ${index} -m mac --mac-source ${src_mac} ${option_time} -j reject
}

create_tod_rule_mac_allow()
{
    local src_mac="$1"
    local option_time="$2"
    local index="$3"

    iptables -I ${chain_timeofday} ${index} -m mac --mac-source ${src_mac} ${option_time} -j RETURN
    iptables -C ${chain_timeofday} -m mac --mac-source ${src_mac} -j reject
    if [ "$?" == "1" ]; then
        iptables -A ${chain_timeofday} -m mac --mac-source ${src_mac} -j reject
    fi

    ip6tables -I ${chain_timeofday} ${index} -m mac --mac-source ${src_mac} ${option_time} -j RETURN
    ip6tables -C ${chain_timeofday} -m mac --mac-source ${src_mac} -j reject
    if [ "$?" == "1" ]; then
        ip6tables -A ${chain_timeofday} -m mac --mac-source ${src_mac} -j reject
    fi
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

    if [ -z "${enabled}" ] || [ "${enabled}" == "0" ]; then
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

    if [ "${mode}" == "allow" -a -z "${option_time}" ]; then
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

    if [ "${type}" == "mac" ]; then
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

create_tod_chain

config_load firewall
config_foreach firewall_zone_check_lan zone

config_load tod
config_foreach tod_host_load host

