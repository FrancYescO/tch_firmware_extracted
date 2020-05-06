#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handler for:	Device.ManagementServer.X_ADB_CWMPState.PostProvisioning
#

AH_NAME="POSTPROVISIONING"

cwmp_state_exec() {
	. /etc/ah/helper_serialize.sh && help_serialize "$AH_NAME" 180
	local ppobj="" path="" value="" prio="" cwmp_progress=""
	for prio in High Default Low; do
		ppobj=$(cmclient GETO "$obj.PostProvisioning.[Priority=$prio]")
		for ppobj in $ppobj; do
			path=$(cmclient GETV "$ppobj.Parameter")
			[ -z "$path" ] && continue
			value=$(cmclient GETV "$ppobj.Value")
			cwmp_progress=$(cmclient GETV Device.ManagementServer.X_ADB_CWMPState.SessionInProgress)
			[ "$cwmp_progress" = "true" ] && exit 0
			cmclient DEL "$ppobj"
			cmclient -u "$AH_NAME" SET "$path" "$value"
			logger -t cwmp -p 5 "Provisioning done: $path=$value"
		done
	done
}

##################
### Start here ###
##################
case "$op" in
s)
	[ "$changedSessionInProgress" = 1 -a "$newSessionInProgress" = "false" ] && cwmp_state_exec &
	;;
esac
exit 0

