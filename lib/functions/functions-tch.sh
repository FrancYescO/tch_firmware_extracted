#!/bin/sh

. /lib/functions.sh

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

#mwan stuff ... 
#mwan mark mask bits
MWAN_MARK_MASK_BITS=15
#Shift size of the mark bits
MWAN_MARK_SHIFT=28

# mwan_get_policy_number <policy> <number>
mwan_get_policy_number()
{
	get_policy_number_cb() {
		local _cfg="$1"
		local _policy="$2"
		local _number="$3"

		i=$(($i+1))
		if [ $_cfg = $_policy ]; then
			export -- "$_number=$i"
			break
		fi
	}
	local i=0

	config_foreach get_policy_number_cb policy "$@"
}

# mwan_get_mark_number <policy> <mark>
mwan_get_mark_number()
{
	local _mark
	local _var=$2

	mwan_get_policy_number $1 _mark
	[ -n "$_mark" ] && {
		val_shift_left "_mark" "$_mark" $MWAN_MARK_SHIFT
		_mark=0x$(printf %x $_mark)
		export -- "$_var=$_mark"
	}
}

# mwan_get_mark_mask <mask>
mwan_get_mark_mask()
{
	local _mask
	local _var=$1

	val_shift_left _mask $MWAN_MARK_MASK_BITS $MWAN_MARK_SHIFT
	_mask=0x$(printf %x $_mask)

	export -- "$_var=$_mask"
}

# setrtprio <name> <prio>
setrtprio() {
	local name=$1
	local prio=$2

	local kthr_pid=`pidof $name`

    #pidof does not work for workqueue threads, try to find pid using other mechanism
    if [ -z "$kthr_pid" ]; then
            kthr_pid=`ps | grep $name | head -1 | cut -d " " -f3`
    fi

	if [ -n "$kthr_pid" ]; then
		chrt -p -r $prio $kthr_pid
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

