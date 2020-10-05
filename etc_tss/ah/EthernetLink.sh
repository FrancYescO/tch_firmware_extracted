#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handler for:	Device.Ethernet.Link.{i}
#                           	Device.Ethernet.Link.{i}.Stats
#

AH_NAME="EthernetLink"

[ "$user" = "${AH_NAME}${obj}" ] && exit 0

# Per-object serialization.
[ "$op" != "g" ] && . /etc/ah/helper_serialize.sh && help_serialize

. /etc/ah/helper_functions.sh
. /etc/ah/helper_status.sh
. /etc/ah/helper_lastChange.sh

service_get() {
	local object="$1" param="$2" ifname lowlayer

	case "${object}.${param}" in
	*".Stats."* )
		ifname=$(cmclient GETV "${object%.*}.Name")
		if [ -n "$ifname" ]; then
			help_get_base_stats "${object}.${param}" "$ifname"
		else
			echo "0"
		fi
		;;
	*".MACAddress" )
		lowlayer=$(cmclient GETV "$object.LowerLayers")
		case "$lowlayer" in
		*"PTM.Link"* | *"Ethernet.Interface"* )
			buf=$(cmclient GETV "$lowlayer.MACAddress")
			echo "$buf"
			;;
		* )
			ifname=$(cmclient GETV "$object.Name")
			if [ -n "$ifname" ]; then
				help_get_base_stats "${object}.${param}" "$ifname"
			fi
			;;
		esac
		;;
	*".LastChange" )
		help_lastChange_get "$object"
		;;
	esac
}

service_config() {
	local _status

	if help_is_set Enable X_ADB_Promisc; then
		[ "$newX_ADB_Promisc" = "true" ] && ifconfig $newName promisc || ifconfig $newName -promisc
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

