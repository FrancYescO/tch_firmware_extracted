#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handler for:	Device.DeviceInfo.MemoryStatus
#

AH_NAME="MemoryStatus"

service_get()
{
	case "$2" in
	"Total" )
		echo $mem_total ;;
	"Free" )
		echo $((mem_free+mem_buffers+mem_cached)) ;;
	"X_ADB_SwapTotal" )
		echo $mem_swaptotal ;;
	"X_ADB_SwapFree" )
		echo $mem_swapfree ;;
	*)
		echo "" ;;
	esac
}

get_mem_info()
{
	local section data

	set -f
	while IFS=" " read -r section data _; do
		case "$section" in
		"MemTotal:")
			mem_total=${data}
			;;
		"MemFree:")
			mem_free=${data}
			;;
		"Buffers:")
			mem_buffers=${data}
			;;
		"Cached:")
			mem_cached=${data}
			;;
		"SwapTotal:")
			mem_swaptotal=${data}
			;;
		"SwapFree:")
			mem_swapfree=${data}
			;;
		esac
	done < /proc/meminfo
	set +f
}

##################
### Start here ###
##################
case "$op" in
g)
	get_mem_info
	for arg; do
		service_get "$obj" "$arg"
	done
	;;
esac
exit 0
