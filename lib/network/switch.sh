#!/bin/sh

configure_switch() {
	local switchname="$1"
	local action=disable
	config_get unit $switchname unit "0"
	config_get jumbo $switchname jumbo "0"
	config_get pauseenabled $switchname qosimppauseenable "0"

	if [ $pauseenabled -eq "1" ]; then
		ethswctl -c regaccess -v 0x28 -l 4 -n $unit -d 0x83ffff
	else
		ethswctl -c regaccess -v 0x28 -l 4 -n $unit -d 0x800000
	fi
	if [ "$unit" -eq "0" ] ; then
		ethswctl -c jumbo -p 9 -v $jumbo > /dev/null
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
