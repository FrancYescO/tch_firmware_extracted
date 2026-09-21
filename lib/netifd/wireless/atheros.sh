#!/bin/sh
# FRV: This script is the minimum needed to be able to let netifd add wireless interfaces.
#      Wireless parameters themselves (ssid,...) are to be updated via
#      hostapd_cli uci_reload
#      OR
#      ubus call wireless reload

NETIFD_MAIN_DIR="${NETIFD_MAIN_DIR:-/lib/netifd}"

. $NETIFD_MAIN_DIR/netifd-wireless.sh

init_wireless_driver "$@"

#FRV: Add device config parameters that are needed below
drv_atheros_init_device_config() {
	dummy=1
}

#FRV: Add iface config parameters that are needed below
drv_atheros_init_iface_config() {
	config_add_int state
}

#FRV: Map radio and interface number to interface name.
atheros_get_if_name() {
	name=$1

	if [ "$g_atheros_radio_name" = "radio_2G" ]; then
		temp=wl0
	elif [ "$g_atheros_radio_name" = "radio_5G" ]; then
		temp=wl1
	else
		temp=wl2
	fi

	if [ "$name" = "0" ] ; then
		g_atheros_if_name="$temp"
	else
		g_atheros_if_name="$temp"_"$name"
	fi
}

#FRV: Setup virtual interface
# -> pass real interface name back to netifd
atheros_setup_vif() {
	local name="$1"

	atheros_get_if_name $name

#	#Enable interface if needed
#	json_select config
#	json_get_var state state
#	json_select ..
#
#	[ "$state" != "0" ] && {
#		ip link set dev "g_atheros_if_name" up || {
#			wireless_setup_vif_failed IFUP_ERROR
#			return
#		}
#	}

	#Add to network
	wireless_add_vif "$name" "$g_atheros_if_name"
}

#FRV: Setup all interfaces of a radio
# -> pass interface names back to netifd via ubus
# -> enable them
drv_atheros_setup() {
	g_atheros_radio_name=$1
#	json_dump
	for_each_interface "sta ap adhoc" atheros_setup_vif
#	wireless_set_data phy=phy0
	wireless_set_up
}

atheros_teardown_vif() {
	local name="$1"

	atheros_get_if_name $name

#	ip link set dev "$g_atheros_if_name" down 2>/dev/null
}

#FRV: Not sure what this should do.
drv_atheros_teardown() {
	g_atheros_radio_name=$1
	for_each_interface "sta ap adhoc" atheros_teardown_vif
#	json_select data
#	json_get_var phy phy
#	json_select ..
#	json_dump
}

drv_atheros_cleanup() {
	dummy=1
}

add_driver atheros
