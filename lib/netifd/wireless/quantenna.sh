#!/bin/sh
# FRV: This script is the minimum needed to be able to let netifd add wireless interfaces.
#      Wireless parameters themselves (ssid,...) are to be updated via
#      hostapd_cli uci_reload
#      OR
#      ubus call wireless reload

. $IPKG_INSTROOT/lib/functions.sh

NETIFD_MAIN_DIR="${NETIFD_MAIN_DIR:-/lib/netifd}"

. $NETIFD_MAIN_DIR/netifd-wireless.sh

init_wireless_driver "$@"

#FRV: Add device config parameters that are needed below
drv_quantenna_init_device_config() {
	dummy=1
}

#FRV: Add iface config parameters that are needed below
drv_quantenna_init_iface_config() {
	config_add_int state
	config_add_string hotspot_timestamp
}

#FRV: Map radio and interface number to interface name.
#!! For quantenna: only one interface is supported for the moment
quantenna_get_if_name() {	
	g_quantenna_if_name=eth5
}

#FRV: Setup virtual interface 
# -> pass real interface name back to netifd
quantenna_setup_vif() {
	local name="$1"

	quantenna_get_if_name $name 

	#Add to network
	wireless_add_vif "$name" "$g_quantenna_if_name"

	#Enable interface if needed
	state=$(uci_get_state "wireless" "$g_quantenna_if_name" "state")

	if [ "$state" != "0" ] ; then
		ifconfig $g_quantenna_if_name up
#	else
#		ifconfig $g_quantenna_if_name down
	fi
}

#FRV: Setup all interfaces of a radio 
# -> pass interface names back to netifd via ubus
# -> enable them
drv_quantenna_setup() {
	g_quantenna_radio_name=$1
#	json_dump
	for_each_interface "sta ap adhoc" quantenna_setup_vif
#	wireless_set_data phy=phy0
	wireless_set_up
}

quantenna_teardown_vif() {
	local name="$1"

	quantenna_get_if_name $name

	ifconfig $g_quantenna_if_name down
}

#FRV: Not sure what this should do.
drv_quantenna_teardown() {
	g_quantenna_radio_name=$1
	for_each_interface "sta ap adhoc" quantenna_teardown_vif
#	json_select data
#	json_get_var phy phy
#	json_select ..
#	json_dump
}

drv_quantenna_cleanup() {
	dummy=1
}

add_driver quantenna
