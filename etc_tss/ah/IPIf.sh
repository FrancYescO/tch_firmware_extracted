#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handler for:	Device.IP.Interface.{i}
#                           	Device.IP.Interface.{i}.Stats
#

AH_NAME="IPIf"

[ "$user" = "${AH_NAME}${obj}" ] && exit 0

# Per-object serialization.
[ "$op" != "g" ] && . /etc/ah/helper_serialize.sh && help_serialize

. /etc/ah/helper_functions.sh
. /etc/ah/helper_ifname.sh
. /etc/ah/helper_status.sh
. /etc/ah/helper_lastChange.sh

service_get() {
	local object="$1" param="$2" ifname lowlayer

	case "${object}.${param}" in
	*".Stats."* )
		help_lowlayer_ifname_get ifname "${obj%.Stats}"
		ifname=$(cmclient GETV "${object%.*}.Name")
		if [ -n "$ifname" ]; then
			help_get_base_stats "${object}.${param}" "$ifname"
		else
			echo "0"
		fi
		;;
	*".LastChange" )
		help_lastChange_get "$object"
		;;
	esac
}

service_config() {
	if help_is_set Enable; then
		help_get_status _status "$obj" "$newEnable"
		if [ "$newStatus" != "$_status" ]; then
			cmclient -u "${AH_NAME}${obj}" SET "$obj.Status" "$_status"
			help_lastChange_set "$obj"
		fi
	fi
	if help_is_changed Status; then
		help_lastChange_set "$obj"
	fi
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
s)
	service_config
	;;
esac
exit 0

