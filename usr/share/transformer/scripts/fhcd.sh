#!/bin/sh

action="$1"
fhcd_running=$(ubus list -S fhcd)

# if fhcd is not running just execute the given action
[ -z "$fhcd_running" ] && {
	eval "$action"
	exit
}

controlmode=$(uci get superwifi.atwifiserv.controlmode)

# if fhcd is running or control mode is active execute the given action using fhcd config_changed
if [ -z "$controlmode" ] || [ $controlmode == "active" ]; then
	doublequote='"'
	backslash='\'
	ubus call fhcd config_changed '{"action":"'"${action//$doublequote/$backslash$doublequote}"'"}'
else
	eval "$action"
fi
