#!/bin/sh

configure_switch() {
	local switchname="$1"
	local action=disable
	config_get unit $switchname unit "0"
	config_get jumbo $switchname jumbo "0"
	chip_id=$(sed -n '/SoC Name/s/.*: *//p' /proc/socinfo)

	if [ "$unit" -eq "0" ] ; then
		case $chip_id in
			*"BCM4910"*|*"BCM68360"*|*"BCM68580"*|*"BCM6755"*)
				ethswctl -c jumbo -p 9 -v $jumbo > /dev/null 2>&1
			;;
			*)
				 ethswctl -c jumbo -p 9 -v $jumbo > /dev/null
			;;
		esac
	fi
	if [ "$unit" -ne "0" ] ; then
		if [ "$jumbo" != "0" ] ; then
			action=enable
		fi
		for p in $(seq 0 8)
		do
			mdkshell $unit:port jumbo $p $action
		done
	fi
}

setup_switch() {
	[ -d "/sys/class/net/bcmsw" ] || return
	config_load network
	# Configure options for all switches
	config_foreach configure_switch switch

	[ -e "/usr/bin/bcmswconfig" ] && {
		bcmswconfig reset
		bcmswconfig load network
	}
}
