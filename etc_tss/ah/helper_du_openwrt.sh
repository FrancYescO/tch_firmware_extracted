#!/bin/sh
#
# Epicentro - TR-181 for Configuration Manager - OpenWrt package
#
# Copyright (C) 2016 ADB Italia
#
# Helper script for DeploymentUnit management
#
# This script is free software, licensed under the GNU General Public License v2.
# See LICENSE for more information.
#

#
# Perform OpenWrt package installation by URL or, if URL is not defined, by name from repository.
#
# $1 package name
# $2 package file URL
# $3 install destination: USB1, or root file system by default
# $4 DU id, not used
#
# If successfull, this function is expected to load package name and version
# in two global variables named 'duname' and 'duversion'
# Return 0 on success, one of the FAULT_* failure codes otherwise
#
helper_du_install() {
	local _duname="$1" _duurl="$2" _dudest="$3"
	local _ret=0 _f1 _f2 _f3
	local _opkgopts="--force-downgrade"

	[ "$_dudest" = "USB1" ] && _opkgopt="${_opkgopt} -d usb1" || _opkgopt="${_opkgopt} -d root"
	if [ -n "$_duurl" ]; then
		opkg install "$_duurl" $_opkgopts > /tmp/opkg-out 2>&1
		_ret=$?
	elif [ -n "$_duname" ]; then
		[ -f /var/opkg-lists/snapshots ] || opkg update
		opkg install "$_duname" $_opkgopts > /tmp/opkg-out 2>&1
		_ret=$?
	else
		_ret=$FAULT_INVALID_ARGS
		return $_ret
	fi
	cat /tmp/opkg-out >> "$LOG_FILE"
	if [ $_ret = 0 ]; then
		set -f
		IFS=" ()"
		while read -r _f1 _f2 _f3 _; do
			case "$_f1" in
			"Installing"|"Upgrading"|"Downgrading")
				duname="$_f2"
				duversion="$_f3"
				;;
			esac
		done < /tmp/opkg-out
		set +f
	else
		_ret=$FAULT_FILE_CORRUPTED
		set -f
		IFS=" :*	"
		while read -r _f1 _f2 _; do
			case "$_f2" in
			"opkg_download")
				_ret=$FAULT_FILE_TRANS_FAILURE
				;;
			"satisfy_dependencies_for")
				_ret=$FAULT_REQUEST_DENIED
				;;
			esac
		done < /tmp/opkg-out
		set +f
	fi
	return $_ret
}

#
# Perform OpenWrt package removal by name.
#
# $1 package name
#
# Return 0 on success, one of the FAULT_* failure codes otherwise
#
helper_du_uninstall() {
	local _duname="$1" _ret=0
	local _f1 _f2

	opkg remove "$_duname" > /tmp/opkg-out 2>&1
	_ret=$?
	cat /tmp/opkg-out >> "$LOG_FILE"
	if [ $_ret != 0 ]; then
		du_log "Error removing package $_duname: $_ret"
		_ret=$FAULT_INTERNAL_ERROR
		set -f
		IFS=" :*	"
		while read -r _f1 _f2 _; do
			case "$_f2" in
			"print_dependents_warning")
				_ret=$FAULT_REQUEST_DENIED
				;;
			esac
		done < /tmp/opkg-out
		set +f
	fi
	return $_ret
}
