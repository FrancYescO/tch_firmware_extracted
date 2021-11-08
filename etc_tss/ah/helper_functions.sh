#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handlers - helper functions
#

# Check whether the given DOM parameters have been changed.
# Usage: help_is_changed Enable Port Interface ...
help_is_changed()
{
	local arg

	for arg; do
		eval [ \"\$changed$arg\" = \"1\" ] && return 0
	done
	return 1
}

# Check whether the given DOM parameters have been set.
# Usage: help_is_set Enable Port Interface ...
help_is_set()
{
	local arg

	for arg; do
		eval [ \"\$set$arg\" = \"1\" ] && return 0
	done
	return 1
}

# Returns the selected network interface statistics
help_get_base_stats_core()
{
	local get_path="$1" ifname="$2" retpar="$3" buf="0"

	if [ -n "$ifname" ] && [ -d /sys/class/net/"$ifname" ]; then
		case "$get_path" in
		*".BytesSent" )
			read buf < /sys/class/net/"$ifname"/statistics/tx_bytes
			;;
		*".DiscardPacketsSent" )
			read buf < /sys/class/net/"$ifname"/statistics/tx_dropped
			;;
		*".PacketsSent" )
			read buf < /sys/class/net/"$ifname"/statistics/tx_packets
			;;
		*".ErrorsSent" )
			read buf < /sys/class/net/"$ifname"/statistics/tx_errors
			;;
		*".BytesReceived" )
			read buf < /sys/class/net/"$ifname"/statistics/rx_bytes
			;;
		*".DiscardPacketsReceived" )
			read buf < /sys/class/net/"$ifname"/statistics/rx_dropped
			;;
		*".PacketsReceived" )
			read buf < /sys/class/net/"$ifname"/statistics/rx_packets
			;;
		*".ErrorsReceived" )
			read buf < /sys/class/net/"$ifname"/statistics/rx_errors
			;;
		*".CRCErrors" )
			read buf < /sys/class/net/"$ifname"/statistics/rx_crc_errors
			;;
		*".MACAddress" )
			read buf < /sys/class/net/"$ifname"/address
			;;
		* )
			buf=""
			;;
		esac
	fi
	eval $retpar='$buf'
}

# Echoes the selected network interface statistics
help_get_base_stats()
{
	local get_path=$1 ifname=$2 retstat

	help_get_base_stats_core $get_path $ifname retstat
	echo "$retstat"
}

help_lowercase() {
	local str="$1"
	local tmp tmpStr=""

	while [ -n "${str%"${str#?}"}" ]; do
		tmp="${str%"${str#?}"}"
		case "$tmp" in
		A) tmpStr="${tmpStr}a" ;;
		B) tmpStr="${tmpStr}b" ;;
		C) tmpStr="${tmpStr}c" ;;
		D) tmpStr="${tmpStr}d" ;;
		E) tmpStr="${tmpStr}e" ;;
		F) tmpStr="${tmpStr}f" ;;
		G) tmpStr="${tmpStr}g" ;;
		H) tmpStr="${tmpStr}h" ;;
		I) tmpStr="${tmpStr}i" ;;
		J) tmpStr="${tmpStr}j" ;;
		K) tmpStr="${tmpStr}k" ;;
		L) tmpStr="${tmpStr}l" ;;
		M) tmpStr="${tmpStr}m" ;;
		N) tmpStr="${tmpStr}n" ;;
		O) tmpStr="${tmpStr}o" ;;
		P) tmpStr="${tmpStr}p" ;;
		Q) tmpStr="${tmpStr}q" ;;
		R) tmpStr="${tmpStr}r" ;;
		S) tmpStr="${tmpStr}s" ;;
		T) tmpStr="${tmpStr}t" ;;
		U) tmpStr="${tmpStr}u" ;;
		V) tmpStr="${tmpStr}v" ;;
		W) tmpStr="${tmpStr}w" ;;
		X) tmpStr="${tmpStr}x" ;;
		Y) tmpStr="${tmpStr}y" ;;
		Z) tmpStr="${tmpStr}z" ;;
		*) tmpStr="${tmpStr}${tmp}" ;;
		esac
		str="${str#?}"
	done
	echo "$tmpStr"
}

help_uppercase() {
	local str="$1"
	local tmp tmpStr

	while [ -n "${str%"${str#?}"}" ]; do
		tmp="${str%"${str#?}"}"
		case "$tmp" in
		a) tmpStr="${tmpStr}A" ;;
		b) tmpStr="${tmpStr}B" ;;
		c) tmpStr="${tmpStr}C" ;;
		d) tmpStr="${tmpStr}D" ;;
		e) tmpStr="${tmpStr}E" ;;
		f) tmpStr="${tmpStr}F" ;;
		g) tmpStr="${tmpStr}G" ;;
		h) tmpStr="${tmpStr}H" ;;
		i) tmpStr="${tmpStr}I" ;;
		j) tmpStr="${tmpStr}J" ;;
		k) tmpStr="${tmpStr}K" ;;
		l) tmpStr="${tmpStr}L" ;;
		m) tmpStr="${tmpStr}M" ;;
		n) tmpStr="${tmpStr}N" ;;
		o) tmpStr="${tmpStr}O" ;;
		p) tmpStr="${tmpStr}P" ;;
		q) tmpStr="${tmpStr}Q" ;;
		r) tmpStr="${tmpStr}R" ;;
		s) tmpStr="${tmpStr}S" ;;
		t) tmpStr="${tmpStr}T" ;;
		u) tmpStr="${tmpStr}U" ;;
		v) tmpStr="${tmpStr}V" ;;
		w) tmpStr="${tmpStr}W" ;;
		x) tmpStr="${tmpStr}X" ;;
		y) tmpStr="${tmpStr}Y" ;;
		z) tmpStr="${tmpStr}Z" ;;
		*) tmpStr="${tmpStr}${tmp}" ;;
		esac
		str="${str#?}"
	done
	echo "$tmpStr"
}

# Usage: help_tr <string1> <string2> <arg>
# It's used to translate in <arg> all the characters specified in <string1> into <string2>
#
help_tr() {
	local str1=$1
	local str2=$2
	local tmp
	set -f
	[ -n "${IFS+x}" ] && local oldifs=$IFS || unset oldifs
	IFS="$str1"
	set -- $3
	[ -n "${oldifs+x}" ] && IFS=$oldifs || unset IFS
	set +f
	[ $# -eq 0 ] && return
	tmp="$1"
	shift
	for arg; do
		tmp="${tmp}${str2}${arg}"
	done
	echo "$tmp"
}

help_uri_escape() {
	local uri="$@"
	local tail="$uri" c
	local tmp=""
	while [ -n "$tail" ] ; do
		tail="${uri#?}"
		c="${uri%"$tail"}"

		case $c in
			[a-zA-Z0-9/.:?\&=@])
				tmp="${tmp}${c}"
				;;
			*)
				tmp="${tmp}%"`echo "$c" | awk 'BEGIN{for(n=0;n<256;n++)ord[sprintf("%c",n)]=n}{printf "%x", ord[$1]}'`
				;;
		esac
		uri=$tail
	done
	echo "$tmp"
}
