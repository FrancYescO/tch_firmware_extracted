#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handlers - helper functions to deal with interface layers and names
#

#
# help_active_lowlayer <ret> <obj-path> [user]
#
help_active_lowlayer() {
	[ "$1" != "__ll" ] && local __ll
	__ll=$(cmclient GETV "$2.X_ADB_ActiveLowerLayer")
	[ ${#__ll} -eq 0 ] && __ll=$(cmclient GETV -u "$3" "$2.LowerLayers")
	__ll=${__ll%%,*}
	eval $1='$__ll'
}

#
# help_lowlayer_ifname_get <ret> <lowlayer> [active ll] [user]
# Recursively search the first meaningful obj name or the lowest physical layer obj name
#
help_lowlayer_ifname_get() {
	[ "$1" != "lowlayer" ] && local lowlayer
	[ "$1" != "ifname" ] && local ifname
	[ "$1" != "vlan" ] && local vlan
	[ "$1" != "suffix" ] && local suffix=""
	lowlayer=$3
	[ ${#lowlayer} -eq 0 ] && lowlayer=${2%%,*}

	while [ ${#lowlayer} -gt 0 ]; do
		ifname=$(cmclient -u "$4" GETV "$lowlayer.Name")
		# Empty ifname and lowlayer does not exists
		if [ ${#ifname} -eq 0 ]; then
			lowlayer=$(cmclient -u "$4" GETO "$lowlayer")
			[ ${#lowlayer} -eq 0 ] && break
		fi
		case $ifname in
		# Meaningful Names: returns them
		ppp* | atm* | ptm* | br* | wwan* | l2tp* | pptp* )
			break
			;;
		# Vlan termination name
		*.* )
			break
			;;
		* )
			# some interfaces allows multiple lowerlayers, try to get the current one
			# or the first one if no other info are provided
			case $lowlayer in
			Device.Ethernet.VLANTermination.*)
				vlan=$(cmclient -u "$4" GETV $lowlayer.VLANID)
				suffix=".$vlan$suffix"
				help_active_lowlayer lowlayer $lowlayer $4
				;;

			Device.Ethernet.Link.*|Device.PPP.Interface.*|Device.IP.Interface.*)
				help_active_lowlayer lowlayer $lowlayer $4
				;;
			*)
				lowlayer=$(cmclient -u "$4" GETV "$lowlayer.LowerLayers")
				;;
			esac
			;;
		esac
	done
	[ ${#ifname} -gt 0 ] && eval $1='$ifname$suffix' || eval $1=''
}

