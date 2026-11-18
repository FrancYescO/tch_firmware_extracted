#!/bin/sh

bin=${0##*/}
. /lib/functions.sh
. /usr/share/libubox/jshn.sh

echo_with_logging()
{
        logger "[$bin]: $@"
        echo "[$bin]: $@"
}

function get_device_role()
{
	UBUS_CMD="ubus -S call wireless.supplicant get"
	UBUS_RESP=`$UBUS_CMD`
	if [ $? -ne 0 ]; then
		echo "repeater"
	else
		# parsing json data
		json_load "$UBUS_RESP"
		json_get_var device_role role
		echo "$device_role"
	fi 
}

function get_connected_state()
{
	local ep_name=$1

	UBUS_CMD="ubus -S call wireless.endpoint get"
	UBUS_RESP=`$UBUS_CMD`
	if [ $? -ne 0 ]; then
		echo "0"
	else
		# parsing json data
		json_load "$UBUS_RESP"
		json_select $ep_name
		json_get_var connected_state connected_state
		echo "$connected_state"
	fi 
}

function get_admin_state()
{
	local ep_name=$1

	UBUS_CMD="ubus -S call wireless.endpoint get"
	UBUS_RESP=`$UBUS_CMD`
	if [ $? -ne 0 ]; then
		echo "0"
	else
		# parsing json data
		json_load "$UBUS_RESP"
		json_select $ep_name
		json_get_var admin_state admin_state
		echo "$admin_state"
	fi 
}

function get_oper_state()
{
	local ep_name=$1

	UBUS_CMD="ubus -S call wireless.endpoint get"
	UBUS_RESP=`$UBUS_CMD`
	if [ $? -ne 0 ]; then
		echo "0"
	else
		# parsing json data
		json_load "$UBUS_RESP"
		json_select $ep_name
		json_get_var oper_state oper_state
		echo "$oper_state"
	fi 
}

function ap_pbc ()
{
	echo_with_logging "Launch AP PBC"
	ubus call wireless wps_button
}

function sta_pbc ()
{
	local ep_name=$1

	echo_with_logging "Launch STA PBC on '$ep_name'"
	ubus call wireless.endpoint.profile enrollee_pbc "{'name' : '$ep_name', 'event' : 'start'}"
}

function start_wps_pbc ()
{
	local ep="ep0"
	local device_role=$(get_device_role)
	local connected_state=$(get_connected_state $ep)
	local admin_state=$(get_admin_state $ep)
	local oper_state=$(get_oper_state $ep)

	echo_with_logging "multiap controller status=$(/etc/init.d/multiap_controller status)"
	echo_with_logging "device_role=${device_role} wireless_connected=${connected_state} $admin_state/$oper_state"

	if [ "${device_role}" == "ap" ]; then
		echo_with_logging "AP PBC - role=${device_role}"
		ap_pbc
	elif [ "${connected_state}" == "1" ]; then
		echo_with_logging "AP PBC - ext is connected with a remote gw"
		ap_pbc
	elif [ "${admin_state}" != "1" ]; then
		echo_with_logging "AP PBC - all endpoints are disabled"
		ap_pbc
	else
		#echo_with_logging "launch PBC on all enabled endpoints"
		# currently only on ep0
		#for endpoint in $(ubus call wireless.endpoint get | grep ep | awk '{print $1}' | cut -f 2 -d\"); do
		if [ "$admin_state"  == "1" ]; then
			echo_with_logging "launch PBC on $ep"
			sta_pbc $ep
		fi
		#done
	fi
}

start_wps_pbc
