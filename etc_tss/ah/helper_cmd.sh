#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Manager - helper functions
#

# Loads the structure of the Data Object Model.
# Usage: help_load_dom [basedir]
help_load_dom()
{
	local dir=${1:-/etc/cm}

	logger -t cm "Loading DOM files from $dir"
	for d in dom domx; do
		for rootd in ${dir}/${d}/*; do
			[ -d "$rootd" ] || continue
			cmclient DOM ${rootd##*/} "$rootd/"
		done
	done
}

# Loads the Data Model configuration.
# Usage: help_load_conf [basedir] [main confdir] [default confdir] [version confdir] [factory confdir]
help_load_conf()
{
	local dir=${1:-/etc/cm}
	local maindir="${dir}/${2:-main}/"
	local defdir="${dir}/${3:-conf}/"
	local verdir="${dir}/${4:-version}/"
	local facdir="${dir}/${5:-factory}/"
	local confdir

	logger -t cm "Setting SAVEPATH to $maindir"
	cmclient SAVEPATH "$maindir"
	[ -f "${maindir}/DeviceInfo.xml" ] && confdir="$maindir" || confdir="$defdir"
	logger -t cm "Loading CONF files from $confdir"
	cmclient CONF "$confdir"
	logger -t cm "Loading VERSION data from $verdir"
	cmclient CONF "$verdir"
	logger -t cm "Loading FACTORY data from $facdir"
	cmclient CONF "$facdir"
}

# Wait for CM process ready.
# Usage: help_wait_cm [timeout] [ctlfile]
help_wait_cm()
{
	local tout=${1:-5}
	local cmctl=${2:-/tmp/cmctl}

	while [ 1 ]; do
		sleep 1
		[ -S "$cmctl" ] && break
		tout=$((tout-1))
		[ $tout -gt 0 ] || return 1
		logger -t cm "Waiting for CM..."
	done
	logger -t cm "Ready"
	return 0
}

