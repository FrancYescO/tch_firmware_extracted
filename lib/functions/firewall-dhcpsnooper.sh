#!/bin/sh
# Copyright (c) 2016 Technicolor
# dhcpsnooper integration for firewall3
#
# The "setup" target is called for firewall3 start.
# The "start" and "stop" are called from the init script.
# The "up" and "down" targets are within the dhcpsnooper instance.


create_dhcpsnooping_chain() {
	iptables -t mangle -N dhcpsnooping 2>/dev/null
	iptables -t mangle -C FORWARD -p udp --sport 67 -j dhcpsnooping 2>/dev/null ||
		iptables -t mangle -A FORWARD -p udp --sport 67 -j dhcpsnooping
	iptables -t mangle -C FORWARD -p udp --dport 67 -j dhcpsnooping 2>/dev/null ||
		iptables -t mangle -A FORWARD -p udp --dport 67 -j dhcpsnooping
}

destroy_dhcpsnooping_chain() {
	iptables -t mangle -F dhcpsnooping 2>/dev/null
	iptables -t mangle -D FORWARD -p udp --sport 67 -j dhcpsnooping 2>/dev/null
	iptables -t mangle -D FORWARD -p udp --dport 67 -j dhcpsnooping 2>/dev/null
	iptables -t mangle -X dhcpsnooping 2>/dev/null
}

json_load_iface_status() {
	local iface="$1"
	local ubus_output="$(ubus call network.interface."$iface" status)"

	json_load "$ubus_output"
}

check_intercept_mode() {
	local iface="$1"
	local intercept_mode=$(uci_get dhcpsnooping."$iface".intercept_mode)

	if [ "$intercept_mode" == "server" ]; then
	  target="sport"
	else
	  target="dport"
	fi
}

create_queue_rule() {
	local l3dev="$1"
	local iface="$2"
	local queue="$3"
	local target

	check_intercept_mode "$iface"

	# pass bridged traffic through the iptables hooks
	echo 1 > /sys/devices/virtual/net/$l3dev/bridge/nf_call_iptables || return 0

	iptables -t mangle -C dhcpsnooping -i "$l3dev" -o "$l3dev" -p udp --$target 67 -j NFQUEUE --queue-num "$queue" 2> /dev/null ||
		iptables -t mangle -A dhcpsnooping -i "$l3dev" -o "$l3dev" -p udp --$target 67 -j NFQUEUE --queue-num "$queue"
}

delete_queue_rule() {
	local l3dev="$1"
	local queue="$2"

	iptables -t mangle -D dhcpsnooping -i "$l3dev" -o "$l3dev" -p udp --sport 67 -j NFQUEUE --queue-num "$queue" 2> /dev/null
	iptables -t mangle -D dhcpsnooping -i "$l3dev" -o "$l3dev" -p udp --dport 67 -j NFQUEUE --queue-num "$queue" 2> /dev/null
}

create_queue_rule_cb() {
	local iface="$1"
	local queue="$2"
	local enable

	config_get_bool enable "$iface" enable "1"
	[ "$enable" -gt 0 ] || return 0

	json_load_iface_status "$iface" || return 0

	process_up "$iface" "$queue"
}

setup_all() {
	. $IPKG_INSTROOT/lib/functions.sh
	. $IPKG_INSTROOT/usr/share/libubox/jshn.sh

	config_load "dhcpsnooping"

	# check if service is enabled
	local enable
	config_get_bool enable global enable 1
	if [ "$enable" -eq 0 ]; then
		# remove chains and rules created previously by this script
		destroy_dhcpsnooping_chain
		return 0
	fi

	create_dhcpsnooping_chain

	local oldrules=$(iptables -t mangle -S dhcpsnooping | grep '^-A' | wc -l)
	local queue
	config_get queue global queue 0

	config_foreach create_queue_rule_cb interface "$queue"

	# remove old rules from dhcpsnooping chain
	while [ $oldrules -gt 0 ]; do
		iptables -t mangle -D dhcpsnooping 1
		oldrules=$((oldrules-1))
	done
}

process_up() {
	local iface="$1"
	local queue="$2"
	local l3_device

	# retrieve the Linux interface name (only when the interface is up)
	json_get_var l3_device l3_device
	[ -n "$l3_device" ] || return
	create_queue_rule "$l3_device" "$iface" "$queue"
}

process_down() {
	local queue="$1"
	local device

	# retrieve the Linux interface name (even when the interface is down)
	json_get_var device device
	[ -n "$device" ] || return
	delete_queue_rule "$device" "$queue"
}

process_updown() {
	local iface="$1"
	local queue="$2"

	. $IPKG_INSTROOT/usr/share/libubox/jshn.sh
	. $IPKG_INSTROOT/lib/functions/network.sh

	json_load_iface_status "$iface" || return

	local up
	json_get_var up up

	[ "$up" -eq 1 ] && process_up "$iface" "$queue" || process_down "$queue"
}

case "${1:-setup}" in
	start) # Called from the init script
	create_dhcpsnooping_chain
	;;

	stop) # Called from the init script
	destroy_dhcpsnooping_chain
	;;

	setup) # Called from fw3 start
	setup_all
	;;

	up)
	local iface="$2"
	local queue="$3"
	. $IPKG_INSTROOT/usr/share/libubox/jshn.sh
	. $IPKG_INSTROOT/lib/functions/network.sh
	json_load_iface_status "$iface" || return
	process_up "$iface" "$queue"
	;;

	down)
	local iface="$2"
	local queue="$3"
	. $IPKG_INSTROOT/usr/share/libubox/jshn.sh
	json_load_iface_status "$iface" || return
	process_down "$queue"
	;;

	updown) # Called from the procd interface trigger
	process_updown "$2" "$3"
	;;

	*) # Unknown target
	return 1
	;;
esac
