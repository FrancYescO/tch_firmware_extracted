#!/bin/sh

. /lib/functions.sh
. ../netifd-proto.sh

[ -n "$INCLUDE_ONLY" ] || {
	init_proto "$@"
}

proto_mobiled_init_config() {
	no_device=1
	available=1
	proto_config_add_int "session_id" "enabled"
	proto_config_add_string "dev_desc" "profile"
}

proto_mobiled_setup() {
	local interface="$1"

	local dev_desc session_id profile enabled
	json_get_vars dev_desc session_id profile enabled

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
		proto_run_command "$interface" /lib/netifd/mobiled.lua -d "$dev_desc" -s "$session_id" -p "$profile" -i "$interface"
	else
		proto_run_command "$interface" /lib/netifd/mobiled.lua -s "$session_id" -p "$profile" -i "$interface"
	fi
}

proto_mobiled_teardown() {
	local interface="$1"
	ubus call network.interface remove '{"interface":"'${interface}_ppp'"}'
	ubus call network.interface remove '{"interface":"'${interface}_4'"}'
	ubus call network.interface remove '{"interface":"'${interface}_6'"}'
	proto_kill_command "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
	add_protocol mobiled
}
