#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handlers - CWMP provisioning helper functions
#

# check for cwmp progress
# append (or update) PostProvisioning object
# return 1 if cwmp is in progress 0 otherwise
help_post_provisioning_add() {
	local cwmp_progress="" path="$1" value="$2" prio="$3" obj="" id="" setm=""
	cwmp_progress=$(cmclient GETV Device.ManagementServer.X_ADB_CWMPState.SessionInProgress)
	if [ "$cwmp_progress" = "true" ]; then
		obj=$(cmclient GETO "ManagementServer.X_ADB_CWMPState.PostProvisioning.[Parameter=$path]")
		if [ -z "$obj" ]; then
			id=$(cmclient ADDS "ManagementServer.X_ADB_CWMPState.PostProvisioning")
			obj="ManagementServer.X_ADB_CWMPState.PostProvisioning.$id"
			logger -t cwmp -p 5 "Provisioning scheduled: $path=$value ($prio priority)"
		fi
		setm="$obj.Parameter=$path"
		setm="$setm	$obj.Value=$value"
		setm="$setm	$obj.Priority=$prio"
		cmclient SETM "$setm"
		return 1
	fi
	return 0
}

# remove PostProvisioning object, if any and return 1
# 0 otherwise
help_post_provisioning_remove() {
	local path="$1" value="$2" elem="" cwmp_progress=""
	cwmp_progress=$(cmclient GETV Device.ManagementServer.X_ADB_CWMPState.SessionInProgress)
	if [ "$cwmp_progress" = "true" ]; then
		elem=$(cmclient GETO "ManagementServer.X_ADB_CWMPState.PostProvisioning.[Parameter=$path].[Value=$value]")
		if [ ${#elem} -gt 0 ]; then
			cmclient DEL "$elem"
			logger -t cwmp -p 5 "Provisioning removed: $path=$value"
			return 1
		else
			return 0
		fi
	fi
	return 0
}
