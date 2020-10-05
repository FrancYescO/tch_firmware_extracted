#!/bin/sh

# Configuration Handler for:	Device.Ethernet.Interface.{i}
#
# This handler performs configuration of Ethernet.Interface.{i} object.
# It is registered on SET on the object:
#       - Device.Ethernet.Interface
# and on GET on parameters:
#	- BytesReceived / BytesSent
#	- ErrorsReceived / Errors Sent
#	- PacketsReceived / PacketsSent
#	- DiscardPacketsReceived / DiscardPacketsSent
#	- LastChange
#
# and it may affect these parameters:
#       - Device.Ethernet.Interface.{i}.Status
#
#	This handler has been certified for SETM usage!
#				,------------------>>>  always check
#		avoid		.__  ,--- ----- ,.  ,.  the original
#		cheap		   \ |---   |   | \/ |  SETM logo!
#		imitations	---' '---   '   '    '  ^^^^^^^^^^^^

AH_NAME="EthernetIf"

[ "$user" = "USER_SKIP_EXEC" ] && exit 0
[ "$user" = "${AH_NAME}${obj}" ] && exit 0
[ "$user" = "${AH_NAME}" ] && exit 0
[ "$user" = "InterfaceMonitor" ] && exit 0

# Per-object serialization.
[ "$op" != "g" ] && . /etc/ah/helper_serialize.sh && help_serialize

. /etc/ah/helper_functions.sh
#. /etc/ah/target.sh

# This is a LOWEST LAYER Module:
# - DO NOT use help_lowlayer_status to retrieve lower layer status -> use instead xxx_link_status
#       (service specific func to retrieve actual status of the physical link)
#
# - DO NOT use help_update_status to adjust new_status on enable value -> new_status is exactly
#       the actual physical link status unless enable is false
#
# - DO NOT check in service_config if called from a lowerlayer status change. It could be instead
#       called by an EH status change on the physical link


service_get() {
	local obj="$1" arg="$2"

	case "$arg" in
	"Status" )
		ifname=$(cmclient GETV "$obj.Name")
		eth_get_link_status "$ifname" ;;
	LastChange)
		. /etc/ah/helper_lastChange.sh
		help_lastChange_get "$obj"
	;;
	* )
		ifname=$(cmclient GETV "${obj%.Stats*}.Name")
		help_get_base_stats "$obj.$arg" "$ifname"
	;;
	esac
}

service_config() {
	# ETHERNET INTERFACE handler has NO LowerLayer attached, so it is called
	# only upon a SET from the eh or the configuration

	# manage Ethernet.Interface.Stats leafs; "X_ADB_Reset = true" reset Ethernet Interface Stats
	case "$obj" in
	*Stats)
		[ "$setX_ADB_Reset" = "1" ] && ethswctl -c test -t 2
		return
		;;
	esac

	# manage Ethernet.Interface objs;
	# reset action is async, since it takes several seconds
	# also be sure to re-acquire the lock into the child process: forking has
	#  put such process outside the mutex protection
	[ "$setX_ADB_Reset" = "1" ] && \
		(help_serialize; eth_set_power "$newName" down; sleep 3; eth_set_power "$newName" up) &

	# Status Change due to an external EVENT: adjust link state and turn up the link
	if [ $changedStatus -eq 1 ]; then
		if [ "$newStatus" = "Down" ]; then
			help_if_link_change "$newName" "$newStatus" "$AH_NAME"
		else
			local _new_status=`eth_get_link_status "$newName"`
			if [ "$newEnable" = "true" -a "$_new_status" = "Up" -a "$user" != "boot" ]; then
				help_if_link_change "$newName" "$newStatus" "$AH_NAME"
			fi
		fi
		exit 0
	fi

	# Retrieve LowLayer.Status of the underlying service.
	local new_status=`eth_get_link_status "$newName"` link_changed=0

	# Adjust new_status if _enable is FALSE
	if [ "$newEnable" = "false" ]; then
		if [ $changedEnable -eq 1 ]; then
			eth_set_power "$newName" down
			link_changed=1
		fi
		new_status="Down"
	else
		# Don't restart the EthernetIf if CWMP re-sets enable on its ConnectionRequestInterface
		if [ "$user" = "CWMP" -a "$setEnable" = "1" -a "$changedEnable" = "0" ]; then
			. /etc/ah/helper_ifname.sh
			help_lowlayer_obj_get tmp '%(Device.ManagementServer.X_ADB_ConnectionRequestInterface)' "$obj"
			[ ${#tmp} -eq 0 ] || exit 0
			unset tmp
		fi
		# Currenty forced at boot for a 10secs cycle
		if [ $changedEnable -eq 1 ]; then
			eth_set_power "$newName" up
		fi

		if [ $setEnable -eq 1 -a "$newUpstream" = "true" ] || [ $changedUpstream -eq 1 ]; then
			eth_set_wan "$newName" "$newUpstream" "true"
		fi
		if [ $changedEnable -eq 1 -o $changedMaxBitRate -eq 1 -o $changedDuplexMode -eq 1 ]; then
			if [ "$newMaxBitRate" = "-1" -o "$newDuplexMode" = "Auto" ]; then
				eth_set_media_type "$newName" Auto
				link_changed=1
			elif [ -n "$newMaxBitRate" -a -n "$newDuplexMode" ]; then
				eth_set_media_type "$newName" "$newMaxBitRate" "$newDuplexMode"
				link_changed=1
			fi
		fi
		# During boot, set media type only if not Auto
		if [ $setEnable -eq 1 -a "$user" = "boot"  ]; then
			if [ "$newMaxBitRate" != "-1" ]; then
				eth_set_media_type "$newName" "$newMaxBitRate" "$newDuplexMode"
				ethsw_power "$newName" "down"
			fi
		fi
		# Currently forced at boot
		if [ $setEnable -eq 1 -o $changedMACAddress -eq 1 -a "$user" = "boot" ] && \
			[ "$newMACAddress" != "$(cat /sys/class/net/"$newName"/address 2>/dev/null)" ]; then
			ip link set "$newName" down
			echo "### $AH_NAME: Executing <ip link set $newName address $newMACAddress> ###"
			ip link set "$newName" address "$newMACAddress" || new_status=Error
		fi
		if [ "$new_status" = "Up" -a "$user" != "boot" ]; then
			echo "### $AH_NAME: Executing <ip link set $newName up> ###"
			ip link set "$newName" up || new_status=Error
		fi
	fi

	# Set eee configuration
	[ "$user" = "boot" -o "$changedEEEEnable" = 1 ] && [ "$newEEECapability" = "true" ] && eth_eee_set $newName $newEEEEnable

	# If changing the link state via an ethctl cmd, do not change the status.
	# It will be changed instead by the Event Handler when the change will actually occur.
	[ "$new_status" != "$newStatus" -a $link_changed -eq 0 -a "$user" != "boot" ] && \
		cmclient SET -u "${AH_NAME}${obj}" "$obj.Status" "$new_status"
}

##################
### Start here ###
##################

case "$op" in
	g)
		case "$obj" in
		*"WANEthernetInterfaceConfig"*)
			obj=$(cmclient GETV "${obj%.Stats*}.X_ADB_TR181Name.Stats")
		;;
		esac
		for arg # Arg list as separate words
		do
			service_get "$obj" "$arg"
		done
		;;
	s)
		service_config
		;;
esac

exit 0

