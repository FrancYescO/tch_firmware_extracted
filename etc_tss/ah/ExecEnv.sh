#!/bin/sh
#
# Epicentro - TR-181 for Configuration Manager
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handler for:	Device.SoftwareModules.ExecEnv
#
# This script is free software, licensed under the GNU General Public License v2.
# See LICENSE for more information.
#
AH_NAME="ExecEnv"

[ "$user" = "${AH_NAME}${obj}" ] && exit 0

. /etc/ah/helper_functions.sh

service_config() {
	if [ "$changedX_ADB_RepositoryURL" = "1" ]; then
		help_execenv_repository $obj "$newX_ADB_RepositoryURL"
	fi
	if [ "$setEnable" = "1" ]; then
		help_execenv_check $obj "$newEnable" "$newX_ADB_SecurityEnable" "$newAllocatedMemory" keep
	fi
	if [ "$setReset" = "1" -a "$newReset" = "true" ]; then
		help_execenv_check $obj false $newX_ADB_SecurityEnable $newAllocatedMemory flush
		help_execenv_reset $obj
		help_execenv_check $obj $newEnable $newX_ADB_SecurityEnable $newAllocatedMemory
	fi
}

service_get() {
	local arg="$1"

	case "$arg" in
		Status)
			echo $execenv_status
		;;
		AllocatedMemory)
			echo $execenv_allocated_mem
		;;
		AvailableMemory)
			echo $execenv_available_mem
		;;
		Version)
			echo $execenv_version
		;;
		X_ADB_UpTime)
			echo $execenv_uptime
		;;
	esac
}

load_helper() {
	local obj="$1" eename helper

	eename=$(cmclient GETV "$obj.Name")
	eename=$(help_lowercase "$eename")
	helper="/etc/ah/helper_execenv_${eename}.sh"
	if [ -x "$helper" ]; then
		. "$helper"
	else
		exit 0
	fi
}

##################
### Start here ###
##################
load_helper "$obj"
case "$op" in
	g)
		help_execenv_status "$obj"
		for arg
		do
			service_get "$arg"
		done
	;;
	s)
		service_config
	;;
	d)
		# nothing to delete
	;;
	a)
		# nothing to add
	;;
esac
exit 0
