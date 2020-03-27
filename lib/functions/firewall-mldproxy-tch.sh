#!/bin/sh
# Copyright (c) 2014 Technicolor

. $IPKG_INSTROOT/lib/functions.sh

setup_mld_input_rules() {
	local zone="$1"

	logger -t mldproxy "Adding input mld query fw rule in zone $zone"
	ip6tables -t filter -I zone_${zone}_input -p icmpv6 --icmpv6-type 130 -s FE80::/16 \
		-j ACCEPT -m comment --comment "Allow ICMPv6-MLD-Query-Input"

	logger -t mldproxy "Adding input mld report fw rule in zone $zone"
	ip6tables -t filter -I zone_${zone}_input -p icmpv6 --icmpv6-type 131 -s FE80::/16 \
		-j ACCEPT -m comment --comment "Allow ICMPv6-MLD-Report-Input"

	logger -t mldproxy "Adding input mld reduction fw in zone $zone"
	ip6tables -t filter -I zone_${zone}_input -p icmpv6 --icmpv6-type 132 -s FE80::/16 \
		-j ACCEPT -m comment --comment "Allow ICMPv6-MLD-Reduction-Input"
}

setup_mcast6_fwd_rule() {
	local zone="$1"

	logger -t mldproxy "Adding forward multicast fw rule in zone $zone"
	ip6tables -t filter -I zone_${zone}_forward -p udp -d FF0E::/16 \
		-j ACCEPT -m comment --comment "Allow UDP-Multicast-Forward"
}

setup_fw6_rules() {
	local iface="$1"

	local state
	config_get state $iface state
	[ "$state" =  "upstream" ] || return

	local zone
	zone=$(fw3 -q network "$iface")

	local handled_zone
	for handled_zone in $HANDLED_ZONES; do
		[ "$handled_zone" = "$zone" ] && return
	done

	setup_mld_input_rules "$zone"
	setup_mcast6_fwd_rule "$zone"

	HANDLED_ZONES="$HANDLED_ZONES $zone"
}

config_load "mldproxy"

local enabled
config_get_bool enabled globals state 0
[ $enabled -eq 0 ] && return 0

config_foreach setup_fw6_rules interface
