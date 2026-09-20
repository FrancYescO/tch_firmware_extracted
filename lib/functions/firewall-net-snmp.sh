#!/bin/sh
# Copyright (c) 2014 Technicolor
# net-snmp integration for firewall3

. $IPKG_INSTROOT/lib/functions.sh

# SNMP
local snmp_enable

setup_snmp_input_rule() {
    local zone="$1"

    iptables -t filter -I zone_${zone}_input -p udp -m udp --dport 161 -m comment --comment "Allow_SNMP_Conn_Reqs" -j ACCEPT
}

setup_snmp_fw_rules() {
    local net="$1"
    local zone

    zone=$(fw3 -q network "$net")

    local handled_zone
    for handled_zone in $HANDLED_SNMP_ZONES; do
        [ "$handled_zone" = "$zone" ] && return
    done

    setup_snmp_input_rule "$zone"

    HANDLED_SNMP_ZONES="$HANDLED_SNMP_ZONES $zone"
}

config_load "snmpd"
config_get_bool snmp_enable general enable 0

    if [ "$snmp_enable" == "1" ]; then
        config_list_foreach general network setup_snmp_fw_rules
    fi

