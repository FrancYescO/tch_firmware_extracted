#!/bin/sh

# To parse ubus output
. /usr/share/libubox/jshn.sh

bin=${0##*/}

enable_ap=0

echo_with_logging()
{
	logger "[$bin]: $@"
	echo "[$bin]: $@"
}

print_help()
{
	echo "Enable or disable a set of APs"
	echo "./$bin          : all APs will be disabled"
	echo "./$bin --enable : all APs (enabled in uci) will be enabled"
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

get_state()
{
	local obj=$1

	local state=$(uci get wireless.$obj.state 2> /dev/null)
	if [ $? -eq 0 ]; then
		echo "$state"
	else
		echo "0"
	fi
}

disable_all_aps()
{
	local state=0

	for ap in $(uci show wireless | grep ^wireless.ap | grep state | grep -v _ | cut -f 2 -d.); do
		local iface=$(get_iface_from_ap $ap)
		wl -i $iface bss down
		echo_with_logging "Disabling $ap|$iface - `wl -i $iface bss`"
	done
}

enable_all_aps()
{
	local state=0

	for ap in $(uci show wireless | grep ^wireless.ap | grep 'state=' | grep -v _ | cut -f 2 -d.); do
		local iface=$(get_iface_from_ap $ap)
		local ap_state=$(get_state $ap)
		local ssid_state=$(get_state $iface)
                echo_with_logging "$ap=$ap iface=$iface ap_state=$ap_state ssid_state=$ssid_state"
 		if [ "$ap_state" == "1" ] && [ "$ssid_state" == "1" ]; then
			wl -i $iface bss up
			echo_with_logging "Enabling $ap|$iface - `wl -i $iface bss`"
		fi
 
	done
}

for i in x x # at most 2 '-' type arguments
do
	case "$1" in
		-h) print_help
			shift;;
		--enable) enable_ap=1
			shift;;
		-*) print_help;;
	esac
done

if [ "$enable_ap" == "1" ]; then
	#enable all ap
	enable_all_aps
else
	#disable all ap
	disable_all_aps
fi
