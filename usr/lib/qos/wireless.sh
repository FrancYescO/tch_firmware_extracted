#!/bin/sh
# Copyright (c) 2014 Technicolor

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh

UCI_BIN="/sbin/uci"
UCI_STATE="/var/state/"

EBT_BIN='/usr/sbin/ebtables'
EBT_TABLE='nat'
EBT_CHAIN='POSTROUTING'
EBT_WMM_CHAIN='post_wmm'

EBT_CMD="$EBT_BIN -t $EBT_TABLE"

ebt_flush() {
    $EBT_CMD --init-table
}

logger "qos-wireless (action=$1)"

case $1 in
    boot)
    ;;
    reload)
        ebt_flush
    ;;
    stop)
        ebt_flush
        exit 0
    ;;
    *)
        logger "qos-wireless error: invalid action"
        exit 1
    ;;
esac

LIST_WMM=
LIST_WL=

list_wl_add() {
  append LIST_WL $1
}

config_load wireless
config_foreach list_wl_add wifi-iface

[ -n "$LIST_WL" ] || exit 0

ebt_wmm_add() {
    local wmm="$1"
    append LIST_WMM $wmm

    config_get mark_ipv4 "$wmm" mark_ipv4 dscp
    config_get mark_ipv6 "$wmm" mark_ipv6 dscp
    config_get mark_802_1q "$wmm" mark_802_1q vlan

    $EBT_CMD -N "$wmm"
    $EBT_CMD -A "$wmm" -p IPV4 -j wmm-mark --wmm-marktag "$mark_ipv4"
    $EBT_CMD -A "$wmm" -p IPV6 -j wmm-mark --wmm-marktag "$mark_ipv6"
    $EBT_CMD -A "$wmm" -p 802_1Q -j wmm-mark --wmm-marktag "$mark_802_1q"
}

ebt_wmm_add_device_rule() {
    local device=$1
    local wmm=$2

    logger "qos-wireless add wmm device ($device -> $wmm)"
    $EBT_CMD -A $EBT_WMM_CHAIN -o "$device" -j "$wmm"
}

ebt_wmm_add_device() {
    local device=$1

    list_contains LIST_WL $device || return
    list_remove LIST_WL $device
    
    config_get_bool enable $device enable 0
    [ $enable = 1 ] || return
    config_get wmm $device wmm
    [ -n "$wmm" ] || return

    ebt_wmm_add_device_rule $device $wmm
}

ebt_wmm_add_default() {
    for device in $LIST_WL
    do
        ebt_wmm_add_device_rule $device wmm_default
    done
}

ebt_wmm_setup() {
    $EBT_CMD -N $EBT_WMM_CHAIN
    $EBT_CMD -A $EBT_CHAIN -j $EBT_WMM_CHAIN

    config_foreach ebt_wmm_add wmm
    list_contains LIST_WMM wmm_default || ebt_wmm_add wmm_default

    config_foreach ebt_wmm_add_device device
    [ -n "$LIST_WL" ] && ebt_wmm_add_default
}

config_load qos
ebt_wmm_setup

