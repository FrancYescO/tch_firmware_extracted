#!/bin/sh
#
# Epicentro - TR-181 for Configuration Manager
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handler for:	Device.SoftwareModules.DeploymentUnit
#
# This script is free software, licensed under the GNU General Public License v2.
# See LICENSE for more information.
#
AH_NAME="SW-DeploymentUnit"

. /etc/ah/helper_serialize.sh && help_serialize "$AH_NAME"
. /etc/ah/helper_functions.sh
. /etc/ah/helper_ifname.sh
# Initialize log file
LOG_FILE=/tmp/sw-du.log
echo "$AH_NAME" > "$LOG_FILE"

# TR069-like exit codes
FAULT_REQUEST_DENIED=1
FAULT_INTERNAL_ERROR=2
FAULT_INVALID_ARGS=3
FAULT_FILE_TRANS_FAILURE=17
FAULT_FILE_CORRUPTED=18
FAULT_EE_UNKNOWN=23
FAULT_EE_DISABLED=24
FAULT_DU_EE_MISMATCH=25
FAULT_DU_DUPLICATED=26
FAULT_RESOURCES_EXCEEDED=27
FAULT_UNKNOWN_DU=28
FAULT_INVALID_STATE=29

du_log() {
	#echo "$*" > /dev/console
	echo "$*" >> "$LOG_FILE"
}

du_load_helper() {
	local eename="$1"
	local ret=0

	eename=$(help_lowercase "$eename")
	helper="/etc/ah/helper_du_${eename}.sh"
	if [ -x "$helper" ]; then
		. "$helper"
	else
		ret=1
	fi
	return $ret
}

du_install() {
	local _duobj="$1" _ret=0

	execenvobj=$(cmclient GETV "$_duobj.ExecutionEnvRef")
	execenv=$(cmclient GETV "$execenvobj.Name")
	if du_load_helper "$execenv"; then
		duname=$(cmclient GETV "$_duobj.Name")
		duurl=$(cmclient GETV "$_duobj.URL")
		dudest=$(cmclient GETV "$_duobj.X_ADB_InstallDest")
		duid=$(cmclient GETV "$_duobj.DUID")
		helper_du_install "$duname" "$duurl" "$dudest" "$duid"
		_ret=$?
	else
		du_log "Don't know how to install sw module to ExecEnv: $execenv"
		_ret=$FAULT_DU_EE_MISMATCH
	fi
	if [ $_ret = 0 ]; then
		# update DeploymentUnit object instance
		_duurl=$(cmclient GETV "$_duobj.URL")
		if [ "$_duurl" != "$duurl" ]; then
			cmclient SETE "$_duobj.URL" "$_duurl"
		fi
		cmclient SETE "$_duobj.Status" "Installed"
	fi
	return $_ret
}

du_uninstall() {
	local _duobj="$1" _ret=0

	duname=$(cmclient GETV "$_duobj.Name")
	execenvobj=$(cmclient GETV "$_duobj.ExecutionEnvRef")
	execenv=$(cmclient GETV "$execenvobj.Name")

	if du_load_helper "$execenv"; then
		helper_du_uninstall "$duname"
		_ret=$?
	else
		du_log "Don't know how to uninstall sw module from ExecEnv: $execenv"
		_ret=$FAULT_DU_EE_MISMATCH
	fi
	if [ $_ret = 0 ]; then
		# update DeploymentUnit object instance
		cmclient SETE "$_duobj.Status" "Uninstalled"
		cmclient SETE "$_duobj.Resolved" "false"
	fi
	return $_ret
}

service_config() {
	local _ret=0

	if [ "$setX_ADB_Operation" = "1" ]; then
		du_log "$newX_ADB_Operation $obj"
		case "$newX_ADB_Operation" in
		Install )
			cmd="Install"
			du_install "$obj"
		;;
		Uninstall )
			cmd="Uninstall"
			du_uninstall "$obj"
		;;
		esac
	fi
	return $_ret
}

du_tr069_install() {
	local _url="$1" _uuid="$2" _username="$3" _password="$4" _execenvobj="$5" _duid="$6"
	local _ret=0 _fext dest url="" name="" ee_obj ee_name ee_enable tmpfile="" _duobj

	[ -n "$_url" ] || return $FAULT_INVALID_ARGS

	# URL can include optional ?dest=USB1 suffix for install destination
	case "$_url" in
	*?dest=USB1)
		dest=USB1
		;;
	*)
		dest=Root
		;;
	esac
	_url=${_url%?dest=*}

	# detect ExecEnv
	_fext=${_url##*.}
	if [ -z "$_execenvobj" ]; then
		for ee_obj in $(cmclient GETO "Device.SoftwareModules.ExecEnv.[X_ADB_FileExt,${_fext}]"); do
			break
		done
		[ -n "$ee_obj" ] || ee_obj="Device.SoftwareModules.ExecEnv.1"
	else
		# strip trailing dot from ExecEnv reference, if any
		ee_obj=${_execenvobj%.}
	fi
	ee_enable=$(cmclient GETV "$ee_obj.Enable")
	[ "$ee_enable" = "true" ] || return $FAULT_EE_DISABLED
	ee_name=$(cmclient GETV "$ee_obj.Name")

	# detect package file source
	case "$_url" in
	file://*|/*)
		url="$_url"
		;;
	http://*|ftp://*|https://*|ftps://*)
		tmpfile="/tmp/"`cut -c1-6 < "/proc/sys/kernel/random/uuid"`."${_fext}"
		> $tmpfile
		wget --user="$_username" --password="$_password" --no-check-certificate -O "$tmpfile" "$_url"
		_ret=$?
		if [ $_ret -ne 0 ]; then
			du_log "Cannot download sw module file: error $_ret"
			rm -f "$tmpfile"
			return $FAULT_FILE_TRANS_FAILURE
		fi
		url="$tmpfile"
		;;
	*)
		name="$_url"
		_url=""
		;;
	esac

	# perform installation
	if du_load_helper "$ee_name"; then
		helper_du_install "$name" "$url" "$dest" "$_duid"
		_ret=$?
	else
		du_log "Don't know how to install sw module to ExecEnv: $ee_name"
		_ret=$FAULT_DU_EE_MISMATCH
	fi
	if [ $_ret = 0 ]; then
		# helper_du_install is expected to load 'duname' and 'duversion' global variables
		if [ -z "$duname" ]; then
			du_log "Error: sw module name is empty"
			_ret=$FAULT_INTERNAL_ERROR
		else
			# update DU object, and create a new instance if needed
			_duobj=$(cmclient ADD "Device.SoftwareModules.DeploymentUnit.[Name=${duname}].[ExecutionEnvRef=${ee_obj}]")
			_duobj="Device.SoftwareModules.DeploymentUnit.${_duobj}"
			[ -n "$duversion" ] && cmclient SETE "$_duobj.Version" "$duversion"
			duuid=$(cmclient GETV "$_duobj.UUID")
			if [ -z "$duuid" -a -z "$_uuid" ]; then
				_uuid=$(du_uuid_gen "$duname" "$duversion")
			fi
			[ -n "$_uuid" ] && cmclient SETE "$_duobj.UUID" "$_uuid"
			[ -n "$_url" ] && cmclient SETE "$_duobj.URL" "$_url"
			cmclient SETE "$_duobj.Resolved" "true"
			cmclient SETE "$_duobj.Status" "Installed"
		fi
	else
		du_log "Error installing sw module"
	fi
	[ -n "$tmpfile" ] && rm -f "$tmpfile"
	return $_ret
}

du_tr069_update() {
	local _uuid=$1 _version=$2 _url=$3 _username=$4 _password=$5 _ret=0 _execenvobj="" _duid=""

	_ret=$FAULT_UNKNOWN_DU

	[ -n "$_uuid" -o -n "$_url" ] || return $FAULT_INVALID_ARGS

	[ -n "$_uuid" ] && quuid=".[UUID=$_uuid]"
	[ -n "$_version" ] && qversion=".[Version=$_version]"
	[ -z "$_uuid" ] && qurl=".[URL=$_url]"
	_duobj=$(cmclient GETO "SoftwareModules.DeploymentUnit${quuid}${qversion}${qurl}")
	if [ -n "$_duobj" ]; then
		[ -z "$_url" ] && _url=$(cmclient GETV "$_duobj.URL")
		[ -z "$_uuid" ] && _uuid=$(cmclient GETV "$_duobj.UUID")
		if [ -n "$_url" ]; then
			_execenvobj=$(cmclient GETV "$_duobj.ExecutionEnvRef")
			_duid=$(cmclient GETV "$_duobj.DUID")
			du_tr069_install "$_url" "$_uuid" "$_username" "$_password" "$_execenvobj" "$_duid"
			_ret=$?
		fi
	fi
	return $_ret
}

du_tr069_uninstall() {
	local _uuid=$1 _version=$2 _execenvobj=$3
	local _ret=0 _dufilter

	# strip trailing dot, if any
	_execenvobj=${_execenvobj%.}
	_dufilter="[UUID=$_uuid]"
	if [ -n "$_version" ]; then
		_dufilter="${_dufilter}.[Version=${_version}]"
	fi
	if [ -n "$_execenvobj" ]; then
		_dufilter="${_dufilter}.[ExecutionEnvRef=${_execenvobj}]"
	fi
	duobj=$(cmclient GETO "SoftwareModules.DeploymentUnit.${_dufilter}")
	if [ -n "$duobj" ]; then
		for duobj in $duobj; do
			du_uninstall "$duobj"
			_ret=$?
			break
		done
	else
		_ret=$FAULT_UNKNOWN_DU
	fi
	return $_ret
}

du_op_update() {
	local _cmd="$1" _code="$2" _opobj="$3" _duobj="$4" _stime="$5" _ctime="$6"
	local _param _value

	cmclient SETE "$_opobj.FaultCode" "$_code"
	cmclient SETE "$_opobj.OperationPerformed" "$_cmd"
	cmclient SETE "$_opobj.StartTime" "$_stime"
	cmclient SETE "$_opobj.CompleteTime" "$_ctime"
	if [ -n "$_duobj" ]; then
		cmclient SETE "$_opobj.DeploymentUnitRef" "$_duobj."
		for _param in UUID Version Resolved; do
			_value=$(cmclient GETV "$_duobj.$_param")
			cmclient SETE "$_opobj.$_param" "$_value"
		done
		_value=$(cmclient GETV "$_duobj.ExecutionUnitList")
		cmclient SETE "$_opobj.ExecutionUnitRefList" "$_value"
	fi
	if [ "$_code" = "0" ]; then
		case "$_cmd" in
		Install | Update)
			_value="Installed"
			;;
		Uninstall)
			_value="Uninstalled"
			;;
		esac
	else
		_value="Failed"
	fi
	cmclient SET "$_opobj.CurrentState" "$_value"
}

auton_du_op_report() {
	local _mserver="$1" _cmd="$2" _code="$3" _duobj="$4" _stime="$5" _ctime="$6"
	local _filter _duscc _opobj _idx

	_filter=$(cmclient GETV "${_mserver}.DUStateChangeComplPolicy.[Enable=true].[OperationTypeFilter,${_cmd}].ResultTypeFilter")
	case "$_filter" in
	Success) [ "$_code" = "0" ] || return ;;
	Failure) [ "$_code" != "0" ] || return ;;
	Both) ;;
	*) return ;;
	esac

	_idx=$(cmclient ADD "$_mserver.X_ADB_CWMPState.DUStateChangeComplete.[Autonomous=true]")
	_duscc="$_mserver.X_ADB_CWMPState.DUStateChangeComplete.$_idx"

	_idx=$(cmclient ADD "$_duscc.Operation")
	_opobj="$_duscc.Operation.$_idx"

	du_op_update "$_cmd" "$_code" "$_opobj" "$_duobj" "$_stime" "$_ctime"
}

du_op_report() {
	local _client="$1" _cmd="$2" _code="$3" _opobj="$4" _duobj="$5" _stime="$6" _ctime="$7"

	if [ -z "$_opobj" ]; then
		# Update ACS with AutonomousDUStateChangeComplete
		if [ "$client" != "cwmp" ]; then
			auton_du_op_report "Device.ManagementServer" "$_cmd" "$_code" "$_duobj" "$_stime" "$_ctime"
		fi
	else
		# Update ACS with DUStateChangeComplete
		du_op_update "$_cmd" "$_code" "$_opobj" "$_duobj" "$_stime" "$_ctime"
	fi
}

##################
### Start here ###
##################
ret=0
stime=`date -u +%FT%TZ`
if [ "$2" = "INSTALL" ]; then
	# client INSTALL URL UUID Username Password ExecEnv.{i} Operation.{i}
	du_log "$1 $2 $3 $4"
	cmd="Install"
	client="$1"
	opobj="$8"
	du_tr069_install "$3" "$4" "$5" "$6" "$7"
	ret=$?
elif [ "$2" = "UPDATE" ]; then
	# client UPDATE UUID Version URL Username Password Operation.{i}
	du_log "$1 $2 $3 $4 $5"
	cmd="Update"
	client="$1"
	opobj="$8"
	du_tr069_update "$3" "$4" "$5" "$6" "$7"
	ret=$?
elif [ "$2" = "UNINSTALL" ]; then
	# client UNINSTALL UUID Version ExecEnv.{i} Operation.{i}
	du_log "$1 $2 $3 $4"
	cmd="Uninstall"
	client="$1"
	opobj="$6"
	du_tr069_uninstall "$3" "$4" "$5"
	ret=$?
elif [ "$op" = "s" ]; then
	# SET operation from CM
	duobj="$obj"
	client="$user"
	opobj=""
	service_config
	ret=$?
else
	# Nothing to do
	exit 0
fi
ctime=`date -u +%FT%TZ`
# Report results to Operation.{i}
[ -n "$cmd" ] && du_op_report "$client" "$cmd" "$ret" "$opobj" "$duobj" "$stime" "$ctime"
exit $ret
