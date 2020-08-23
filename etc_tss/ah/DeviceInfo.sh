#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handler for:	Device.DeviceInfo
#

AH_NAME="DeviceInfo"

service_get()
{
	case "$2" in
	"UpTime")
		IFS=. read uptime _ < /proc/uptime
		echo "$uptime"
		;;
	esac
}

##################
### Start here ###
##################
case "$op" in
g)
	for arg; do
		service_get "$obj" "$arg"
	done
	;;
esac
exit 0

