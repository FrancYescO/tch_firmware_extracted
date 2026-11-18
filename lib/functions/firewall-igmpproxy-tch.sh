#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh

setup_igmp_input_rule() {
	local zone="$1"

	logger -t igmpproxy "Adding input igmp fw rule in zone $zone"
	iptables -t filter -I zone_${zone}_input -p igmp -j ACCEPT \
		-m comment --comment "Allow IGMP-Input"
}

setup_mcast_fwd_rule() {
	local zone="$1"

	logger -t igmpproxy "Adding forward multicast fw rule in zone $zone"
	iptables -t filter -I zone_${zone}_forward -p udp -d 224.0.0.0/4 \
		-j ACCEPT -m comment --comment "Allow UDP-Multicast-Forward"
}

setup_fw_rules() {
	local iface="$1"

	local state
	config_get state "$iface" state

	[ "$state" = "upstream" ] || return

	local zone
	zone=$(fw3 -q network "$iface")

	local handled_zone
	for handled_zone in $HANDLED_ZONES; do
		[ "$handled_zone" = "$zone" ] && return
	done

	setup_igmp_input_rule "$zone"
	setup_mcast_fwd_rule "$zone"

	HANDLED_ZONES="$HANDLED_ZONES $zone"
}

config_load "igmpproxy"

local enabled
config_get_bool enabled globals state 0
[ $enabled -eq 0 ] && return 0

config_foreach setup_fw_rules interface
