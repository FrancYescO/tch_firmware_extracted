#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh

exclude=
blocked_page_redirect=

clean_tables() {
    # deleting weburlfilter from forwarding rule
    iptables -D forwarding_rule -j weburlfilter >/dev/null 2>&1

    # deleting weburlfilter chain
    iptables -F weburlfilter >/dev/null 2>&1
    iptables -X weburlfilter >/dev/null 2>&1
}

insert_site_rule() {
    local site_keyword=$1
    local device=$2
    local mac=$3
    local action=$4
    local weburl_action=
    local dev_str=""
    local mac_str=""
    local tmp

    if [ -n "$action" ]
    then
        # detail rules action will override global action
        weburl_action="$(echo $action | tr [a-z] [A-Z])"
    elif [ "$exclude" = "1" ]
    then
        weburl_action="DROP"
    else
        weburl_action="ACCEPT"
    fi

    tmp=$(echo $device | tr [A-Z] [a-z])

    if [ "$tmp" != "all" ]
    then
        dev_str="-s $device"
    fi

    if [ -n "$mac" ]
    then
        mac_str="-m mac --mac-source $mac"
    fi

    if [ -n "$site_keyword" ]
    then
        site_keyword="-m weburl --contains $site_keyword"
    fi

    iptables -A weburlfilter $site_keyword $dev_str $mac_str -j $weburl_action
}


handle_urlfilter_inst() {
    local name="$1"
    local device site action

    config_get device "$name" device "All"
    config_get site "$name" site ""
    config_get mac "$name" mac ""
    config_get action "$name" action ""

    site=$(echo $site | tr [A-Z] [a-z])
    site=${site#http://}
    # busybox doesn't support variable replacement as below, so recover old way
    # site=${site/#www./.}
    if [ "${site:0:4}" = "www." ]
    then
        site=${site:3}
    fi

    if [ -z "$site" -a -z "$device" -a -z "$mac" ]
    then
        return
    fi

    insert_site_rule "$site" "$device" "$mac" "$action"
}


insert_tables() {
    # creating weburlfilter chain
    iptables -N weburlfilter
    iptables -A weburlfilter -p tcp --dport 80 -j SKIPLOG

    # insert the chain into the forwarding_rule
    iptables -I forwarding_rule -j weburlfilter

    config_foreach handle_urlfilter_inst URLfilter

    if [ "$exclude" != "1" ]
    then
        iptables -A weburlfilter -m weburl --contains_regex ".*" -j DROP
    fi

}

start() {
    local enable

    clean_tables

    config_load parental

    config_get_bool enable general enable 1

    if [ "$enable" != '1' ]
    then
        return
    fi

    config_get_bool exclude general exclude 0

    config_get blocked_page_redirect redirect blocked_page_redirect ""

    insert_tables
}

start
