#!/bin/sh
# FRV: This script is the minimum needed to be able to let netifd add wireless interfaces.
#      Wireless parameters themselves (ssid,...) are to be updated via
#      hostapd_cli uci_reload
#      OR
#      ubus call wireless reload

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/network/config.sh

NETIFD_MAIN_DIR="${NETIFD_MAIN_DIR:-/lib/netifd}"

. $NETIFD_MAIN_DIR/netifd-wireless.sh

init_wireless_driver "$@"

#FRV: Add device config parameters that are needed below
drv_broadcom_init_device_config() {
	dummy=1
}

#FRV: Add iface config parameters that are needed below
drv_broadcom_init_iface_config() {
	config_add_int state
	config_add_string hotspot_timestamp
}

#FRV: Map radio and interface number to interface name.
broadcom_get_if_name() {
	name=$1

	if [ "$g_broadcom_radio_name" = "radio_2G" ] ; then
		temp=wl0
	else
		temp=wl1
	fi
	
	if [ "$name" = "0" ] ; then
		g_broadcom_if_name="$temp"
	else
		g_broadcom_if_name="$temp"_"$name" 
	fi
}

#FRV: Setup virtual interface 
# -> pass real interface name back to netifd
broadcom_setup_vif() {
	local name="$1"

	broadcom_get_if_name $name 

	#Add to network
	wireless_add_vif "$name" "$g_broadcom_if_name"

	#Enable interface if needed
	state=$(uci_get_state "wireless" "$g_broadcom_if_name" "state")

	if [ "$state" != "0" ] ; then
		ifconfig $g_broadcom_if_name up
#	else
#		ifconfig $g_broadcom_if_name down
	fi
}

#FRV: Setup all interfaces of a radio 
# -> pass interface names back to netifd via ubus
# -> enable them
drv_broadcom_setup() {
	g_broadcom_radio_name=$1
#	json_dump
	for_each_interface "sta ap adhoc" broadcom_setup_vif
#	wireless_set_data phy=phy0
	wireless_set_up
}

broadcom_teardown_vif() {
	local name="$1"
	local bridge

	json_get_var bridge bridge

	broadcom_get_if_name $name

	ifconfig $g_broadcom_if_name down

	if [ -n "$bridge" ]; then
		local if=$(find_config "$bridge")
		json_set_namespace tmp old
		json_init
		json_add_string name "$g_broadcom_if_name"
		json_add_boolean link-ext 1
		json_close_object
		if [ -n "$if" ]; then
			ubus call network.interface.$if remove_device "$(json_dump)"
		fi
		json_set_namespace $old
	fi
}

#FRV: Not sure what this should do.
drv_broadcom_teardown() {
	g_broadcom_radio_name=$1
	for_each_interface "sta ap adhoc" broadcom_teardown_vif
#	json_select data
#	json_get_var phy phy
#	json_select ..
#	json_dump
}

drv_broadcom_cleanup() {
	dummy=1
}

add_driver broadcom
