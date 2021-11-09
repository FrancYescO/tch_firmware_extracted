#!/bin/sh

# To parse ubus output
. /usr/share/libubox/jshn.sh

bin=${0##*/}

aps=""
mode=""

echo_with_logging()
{
	logger "[$bin]: $@"
	echo "[$bin]: $@"
}

print_help()
{
	echo "Enable or disable a set of APs"
	echo "./$bin -> all APs will be disabled"
	echo "./$bin  -a 'ap0,ap1'  -m enable_ap  -> will enable ap0,ap1"
	echo "./$bin  -a 'ap0,ap1'  -m disable_ap  -> will disable ap0,ap1"
	exit 1
}

get_iface_from_ap()
{
	local ap=$1

	iface=$(uci get wireless.$ap.iface 2> /dev/null)
	if [ $? -eq 0 ]; then
		echo "$iface"
	else
		echo ""
	fi
}

disable_all_ap_ifaces()
{
	local state=0

	for ap in $(uci show wireless | grep ^wireless.ap | grep state | grep -v _ | cut -f 2 -d.); do
		local iface=$(get_iface_from_ap $ap)
		wl -i $iface bss down
		echo_with_logging "Setting state for $ap|$iface to $state curr:`wl -i $iface isup`"
	done
}

enable_ap()
{
	ap=$1
	state=$2
        local iface=$(get_iface_from_ap $ap)

        if [ "$state" == 1 ]; then
		wl -i $iface bss up
		echo_with_logging "Enabling $ap|$iface curr:`wl -i $iface isup`"
	else
		wl -i $iface bss down
		echo_with_logging "Disabling $ap|$iface curr:`wl -i $iface isup`"
	fi
}

for i in x x x # at most 3 '-' type arguments
do
	case "$1" in
		-h) print_help
			shift;;
		-a) aps="$2"
			shift;
			shift;;
		-m) mode="$2"
			shift;
			shift;;
		-*) print_help;;
	esac
done

if [ -z $aps ]; then
	echo_with_logging "disable all APs"
	disable_all_ap_ifaces
	exit
fi

if [ "$mode" != "enable_ap" ] && [ "$mode" != "disable_ap" ]; then
	echo "-m <mode> needs to be either 'enable_ap' or 'disable_ap'"
	print_help
fi

if [ "$mode"  == "enable_ap" ]; then
	# enable APs
	for ap in $(echo $aps | sed "s/,/ /g"); do
		enable_ap $ap 1
	done
else
	# disable APs
	for ap in $(echo $aps | sed "s/,/ /g"); do
		enable_ap $ap 0
	done
fi
