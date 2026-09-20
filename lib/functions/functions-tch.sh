#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh

# find_zone <interface> <zone variable>
find_zone() {
	find_zone_cb() {
		local cfg="$1"
		local iface="$2"
		local var="$3"

		local name
		config_get name "$cfg" name

		local network
		config_get network "$cfg" network

		list_contains network $iface && {
			export -- "$var=$name"
			break
		}
	}

	config_foreach find_zone_cb zone "$@"
}

# val_shift_left <shifted value> <value to be shifted> <shift value>
val_shift_left() {
	local _var="$1"
	local _val="$2"
	local _shift="$3"
	local i=0

	while [ $i -lt $_shift ];
	do
		_val=$(($_val+$_val))
		i=$((i+1))
	done

	export -- "$_var=$_val"
}

# setrtprio <name> <prio> [rr|fifo]
# [rr|fifo] is an optional paramter, rr to set task to SCHED_RR, fifo to set task to SCHED_FIFO, 
#           default is SCHED_RR if it's lack
setrtprio() {
	local name=$1
	local prio=$2
	local type=$3

	local kthr_pid=`pidof $name`

	#pidof does not work for workqueue threads, try to find pid using other mechanism
	if [ -z "$kthr_pid" ]; then
		kthr_pid=`ps | grep $name | head -1 | cut -d " " -f3`
	fi

	if [ -n "$kthr_pid" ]; then
		case $type in
		rr)
			chrt -p -r $prio $kthr_pid;;
		fifo)
			chrt -p -f $prio $kthr_pid;;
		*)
			chrt -p -r $prio $kthr_pid;;
		esac
	fi
}

# setcpumask <name> <mask>
setcpumask() {
	local name=$1
	local mask=$2

	local kthr_pid=`pidof $name`

	if [ -n "$kthr_pid" ]; then
		taskset -p $mask $kthr_pid
	fi
}

# process_exists <name>
process_exists() {
	local name=$1

	local kthr_pid=`pidof $name`

	if [ -n "$kthr_pid" ]; then
		echo "1"
	else
		echo "0"
	fi
}

load_hardware_info() {
  if [ -d '/sys/class/net/bcmsw' ] ; then
    VENDOR='Broadcom'
    HARDWARE=$(sed -n '/Hardware/s/.*: *//p' /proc/cpuinfo)
  fi
}
