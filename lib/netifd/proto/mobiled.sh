#!/bin/sh

. /lib/functions.sh
. ../netifd-proto.sh

[ -n "$INCLUDE_ONLY" ] || {
	init_proto "$@"
}

proto_mobiled_init_config() {
	no_device=1
	available=1
	proto_config_add_int "session_id" "enabled" "optional"
	proto_config_add_string "dev_desc" "profile" "bridge" "name"
}

check_and_remove() {
	local interface="$1"
	if ubus list network.interface.${interface}; then
		ubus call "network.interface.${interface}" remove
	fi
}

proto_mobiled_setup() {
	local interface="$1"

	local dev_desc session_id profile enabled optional bridge name
	json_get_vars dev_desc session_id profile enabled optional bridge name

	if [ -z "$session_id" ]; then
		proto_notify_error "$interface" "No assigned session ID"
		proto_set_available "$interface" 0
		return 1
	fi

	if [ -z "$profile" ]; then
		proto_notify_error "$interface" "No assigned profile"
		proto_set_available "$interface" 0
		return 1
	fi

	if [ "$enabled" = "0" ]; then
		proto_set_available "$interface" 0
		return 1
	fi

	if [ -n "$dev_desc" ]; then
		dev_desc_option="-d $dev_desc"
	fi

	if [ "$optional" = "1" ]; then
		optional_option="-o"
	fi

	if [ -n "$bridge" ]; then
		bridge_option="-b $bridge"
	fi

	if [ -n "$name" ]; then
		name_option="-n $name"
	fi

	proto_run_command "$interface" /lib/netifd/mobiled.lua ${dev_desc_option} -s "$session_id" -p "$profile" -i "$interface" ${optional_option} ${bridge_option} ${name_option}
}

proto_mobiled_teardown() {
	local interface="$1"
	check_and_remove "${interface}_ppp"
	check_and_remove "${interface}_4"
	check_and_remove "${interface}_6"
	proto_kill_command "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
	add_protocol mobiled
}
