#!/bin/sh

bin=${0##*/}

function ap_pbc ()
{
	logger "[$bin] Launch AP PBC"
	ubus call wireless wps_button
}

function sta_pbc ()
{
	local ep_name=$1

	logger "[$bin] Launch STA PBC on '$ep_name'"
	ubus call wireless.endpoint.profile enrollee_pbc "{'name' : '$ep_name', 'event' : 'start'}"
}

function wps_pbc ()
{
	ubus_call="ubus call wireless.endpoint get 2> /dev/null | grep '\"connected_state\": 1'"
	connected_state="`eval $ubus_call`"

	ubus_call="ubus call wireless.endpoint get 2> /dev/null | grep '\"admin_state\": 1'"
	admin_state="`eval $ubus_call`"

	if [ ! -z "${connected_state}" ]; then
		logger "[$bin] AP PBC - ext is connected with a remote gw"
		ap_pbc
	elif [ -z "${admin_state}" ]; then
		logger "[$bin] AP PBC - all endpoints are disabled"
		ap_pbc
	else
		logger "[$bin] launch PBC on all enabled endpoints"

		for endpoint in $(ubus call wireless.endpoint get | grep ep | awk '{print $1}' | cut -f 2 -d\"); do

			local ubus_call="ubus call wireless.endpoint get '{ \"name\" : \"$endpoint\" }' | grep oper_state | cut -d' ' -f 2 | cut -f 1 -d,"
			local oper_state="`eval $ubus_call`"

			local ubus_call="ubus call wireless.endpoint get '{ \"name\" : \"$endpoint\" }' | grep admin_state | cut -d' ' -f 2 | cut -f 1 -d,"
			local admin_state="`eval $ubus_call`"

			if [ "$admin_state"  == "1" ]; then
				logger "[$bin] launch PBC on all enabled endpoints, iface: $ssid_name, admin_state: $admin_state, oper_state: $oper_state"
				sta_pbc $endpoint
			fi
		done
	fi
}

wps_pbc
