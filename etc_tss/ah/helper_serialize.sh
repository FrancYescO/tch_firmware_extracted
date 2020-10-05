#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handlers - helper functions for scripts serialization
#

help_append_trap() {
	local cmd=$1
	local signal=$2
	local save_traps=`trap`
	local x

	while IFS= read -r x; do
		case "$x" in
			*" $signal")
				x="'${x#*'}"
				eval x="${x%'*}'"
				case ";$x;" in
					*";$cmd;"*)
						return
						;;
					*)
						cmd="$cmd;$x"
						;;
				esac
				;;
		esac
	done <<-EOF
		$save_traps
	EOF
	trap "$cmd" "$signal"
}

help_serialize() {
	if [ $# -eq 0 -a ${#AH_NAME} -eq 0 ]; then
		echo "$0: Please use help_serialize <parameter> [timeout] or define AH_NAME." >/dev/console
		exit 1
	fi
	local lockdir="/tmp/lock/${1:-ah_${AH_NAME}${obj}}" i=0 x mystarttime starttime timeout trap

	if [ "$2" = "notrap" ]; then
		timeout=$((${3:-60} * 10))
		trap=0
	else
		timeout=$((${2:-60} * 10))
		trap=1
	fi

	mkdir -p "${lockdir}-$$.pid" 2>/dev/null || return
	if [ -e /proc/$$/stat ]; then
		read _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ mystarttime _ </proc/$$/stat
	fi
	while :; do
		i=0
		until mkdir "${lockdir}" 2>/dev/null; do
			i=$((i+1))
			usleep 100000
			if [ ${i} -ge $timeout ]; then
				# If there aren't another real lock, then delete the master lock
				set -- "${lockdir}"-*.pid
				if [ $# -eq 1 ] && [ "$1" = "${lockdir}-$$.pid" ]; then
					rm -r "${lockdir}" 2>/dev/null
				else
					echo "${lockdir##*/}: stale or long lock detected" >/dev/console
					echo "${lockdir}"
					logger -t "SYSTEM" -p 2 "ARS 9 - Stale lock detected while updating system status: [${lockdir##*/}]"
					rm -r "${lockdir}-$$.pid" 2>/dev/null
					return 1
				fi
			fi
		done
		for x in "${lockdir}"-*.pid; do
			starttime=0
			x=${x##*-}
			x=${x%.pid}
			if [ -e /proc/"$x"/stat ]; then
				read _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ starttime _ 2>/dev/null </proc/"$x"/stat
			fi
			if [ $starttime -ne 0 ] && [ $starttime -lt $mystarttime ]; then
				rm -r "${lockdir}" 2>/dev/null
				sleep 0.1
				continue 2
			fi
		done
		break
	done

	echo "${lockdir}"

	if [ $trap -eq 1 ]; then
		help_append_trap "rm -r \"${lockdir}\" \"${lockdir}-$$.pid\" 2>/dev/null" "EXIT"
		trap "exit" INT TERM
	fi
}

help_serialize_nowait() {
	if [ $# -eq 0 -a ${#AH_NAME} -eq 0 ]; then
		echo "$0: Please use help_serialize_nowait <parameter> or define AH_NAME." >/dev/console
		exit 1
	fi
	local lockdir="/tmp/lock/${1:-ah_${AH_NAME}${obj}}"
	local i=0
	local x

	if [ "$2" != "notrap" ]; then
		help_append_trap "rm -r \"${lockdir}\" 2>/dev/null" "EXIT"
		trap "exit" INT TERM
	fi

	until mkdir "${lockdir}" 2>/dev/null; do
		i=$((i+1))
		sleep 0.1
	done

	echo "${lockdir}"
}

help_serialize_unlock() {
	if [ $# -eq 0 -a ${#AH_NAME} -eq 0 ]; then
		echo "$0: Please use help_serialize_unlock <parameter> or define AH_NAME." >/dev/console
		exit 1
	fi
	local lockdir="/tmp/lock/${1:-ah_${AH_NAME}${obj}}"

	rm -r "${lockdir}" "${lockdir}-$$.pid" 2>/dev/null
	:
}

help_serialize_run_once() {
	if [ $# -eq 0 -a ${#AH_NAME} -eq 0 ]; then
		echo "$0: Please use help_serialize_run_once <parameter> or define AH_NAME." >/dev/console
		exit 1
	fi
	local lockdir="/tmp/lock/${1:-ah_${AH_NAME}${obj}}"

	if [ "$2" != "notrap" ]; then
		help_append_trap "rm -r \"${lockdir}\" 2>/dev/null" "EXIT"
		trap "exit" INT TERM
	fi

	mkdir "${lockdir}" 2>/dev/null || exit 0
	echo "${lockdir}"
}

help_sem_get() {
	local sem_file="/tmp/lock/$1.count"
	local count=0

	[ -f $sem_file ] && count="`cat $sem_file`"
	echo -n $count
}

_help_sem_set() {
	local sem_file="/tmp/lock/$1.count"
	local count=${2:-0}

	if [ $count -eq 0 ]; then
		rm -f $sem_file
	else
		echo $count > $sem_file
	fi
}

help_sem_set() {
	local sem_lock
	local count=${2:-0}

	sem_lock=`help_serialize_nowait "$1.lock" notrap`
	_help_sem_set $1 $count
	help_serialize_unlock "$1.lock"
	echo -n $count
}

help_sem_signal() {
	local sem_lock
	local delta=${2:-1}
	local count

	sem_lock=`help_serialize_nowait "$1.lock" notrap`
	count="`help_sem_get $1`"
	count=$(($count+$delta))
	_help_sem_set $1 $count
	help_serialize_unlock "$1.lock"
	echo -n $count
}

help_sem_wait() {
	local sem_lock
	local delta=${2:-1}
	local count

	sem_lock=`help_serialize_nowait "$1.lock" notrap`
	count="`help_sem_get $1`"
	count=$(($count-$delta))
	_help_sem_set $1 $count
	help_serialize_unlock "$1.lock"

	while [ $count -lt 0 ]; do
		count=`help_sem_get $1`
		[ $count -ge 0 ] && break
		sleep 0.1
	done
	echo -n $count
}

