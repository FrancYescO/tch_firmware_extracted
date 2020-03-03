#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handlers - helper functions for Status management
#

#
# help_get_status_from_lowerlayers <ret> <obj_path> [enable] [ll] [ll_is_status]
# Search Status params of all the objs defined in obj_path.LowerLayers, or [ll],
# if provided. if [ll_is_status] is set, assume that ll is old lower layer
# status, elsewhere assume that [ll] is the list of the current lower layers
# Evals in order of precedence:
#	- "Down": if obj_path.Enable (or [enable]) parameter is false 
#	- "Up": if at least one of the LowerLayers objs is in Up state
#	- "Error": if at least one of the LowerLayers objs is in Error state
#	- "Dormant": if at least one of the LowerLayers objs is in Dormant state
#	- "LowerLayerDown": if all the LowerLayers objs are in NotPresent state but
#	                    at least one is in Down or LowerLayerDown
#	- "NotPresent": if all the LowerLayers objs are in NotPresent state
#
help_get_status_from_lowerlayers() {
	[ "$1" != "arg" ] && local arg
	[ "$1" != "new_status" ] && local new_status

	[ ${#3} -eq 0 ] && arg=$(cmclient GETV "$2.Enable") || arg="$3"
	if [ "$arg" = "false" ]; then
		eval $1='Down'
		return
	fi
	[ ${#4} -eq 0 ] && arg=$(cmclient GETV "$2.LowerLayers") || arg="$4"
	[ -n "${IFS+x}" ] && local oldifs=$IFS || unset oldifs
	IFS=','
	new_status=""
	for arg in $arg; do
		[ ${#5} -eq 0 ] && arg=$(cmclient GETV "$arg.Status")
		case $arg in
		"Up")
			new_status="Up"
			break
			;;
		"Error")
			new_status="Error"
			;;
		"Dormant")
			[ "$new_status" != "Error" ] && new_status="Dormant"
			;;
		"NotPresent")
			[ -z "$new_status" ] && new_status="NotPresent"
			;;
		"Down" | "LowerLayerDown")
			[ -z "$new_status" -o "$new_status" = "NotPresent" ] && new_status="LowerLayerDown"
			;;
		esac
	done
	[ -z "new_status" ] && new_status="LowerLayerDown"
	[ -n "${oldifs+x}" ] && IFS=$oldifs || unset IFS
	eval $1='$new_status'
}

#
# help_get_status_from_operstate <ret> <obj> [enable]
# Evaluate the Status parameter of <obj> interface layer, and return the value in <ret> variable.
# The Enable parameter value can be provided with the optional [enable].
# Status is retrieved by the network device operational status.
#
help_get_status_from_operstate() {
	[ "$1" != "arg" ] && local arg
	[ "$1" != "new_status" ] && local new_status
	[ "$1" != "name" ] && local name

	[ ${#3} -eq 0 ] && arg=$(cmclient GETV "$2.Enable") || arg="$3"
	if [ "$arg" = "false" ]; then
		eval $1='Down'
		return
	fi
	name=$(cmclient GETV ${obj}.Name)
	read arg < "/sys/class/net/${name}/operstate"
	case "$arg" in
	"unknown") new_status=Unknown ;;
	"notpresent") new_status=NotPresent ;;
	"down") new_status=Down ;;
	"lowerlayerdown") new_status=LoweLayerDown ;;
	"dormant") new_status=Dormant ;;
	"up") new_status=Up ;;
	*) new_status=Error ;;
	esac
	eval $1='$new_status'
}

#
# help_get_status <ret> <obj> [enable] [ll]
# Evaluate the Status parameter of <obj> interface layer, and return the value in <ret> variable.
# The Enable parameter value can be provided with the optional [enable].
# The LowerLayers parameter value can be provided with the optional [ll].
# Status is retrieved by lower layers, if any, or by the network device operational status.
#
help_get_status() {
	[ "$1" != "arg" ] && local arg

	[ ${#4} -eq 0 ] && arg=$(cmclient GETV "$2.LowerLayers") || arg="$4"
	if [ ${#arg} -eq 0 ]; then
		help_get_status_from_operstate "$1" "$2" "$3"
	else
		help_get_status_from_lowerlayers "$1" "$2" "$3" "$4"
	fi
}
