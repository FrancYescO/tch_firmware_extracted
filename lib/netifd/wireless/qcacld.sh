#!/bin/sh
# FRV: This script is the minimum needed to be able to let netifd add wireless interfaces.
#      Wireless parameters themselves (ssid,...) are to be updated via
#      hostapd_cli uci_reload
#      OR
#      ubus call wireless reload

. $IPKG_INSTROOT/lib/network/config.sh

NETIFD_MAIN_DIR="${NETIFD_MAIN_DIR:-/lib/netifd}"

. $NETIFD_MAIN_DIR/netifd-wireless.sh

init_wireless_driver "$@"

#FRV: Add device config parameters that are needed below
drv_qcacld_init_device_config() {
	dummy=1
}

#FRV: Add iface config parameters that are needed below
drv_qcacld_init_iface_config() {
	config_add_int state
}

#FRV: Map radio and interface number to interface name.
qcacld_get_if_name() {
	name=$1

	if [ "$g_qcacld_radio_name" = "radio_2G" ] ; then
		temp=wl0
	else
		temp=wl1
	fi
	
	if [ "$name" = "0" ] ; then
		g_qcacld_if_name="$temp"
	else
		g_qcacld_if_name="$temp"_"$name" 
	fi
}

#FRV: Setup virtual interface 
# -> pass real interface name back to netifd
qcacld_setup_vif() {
	local name="$1"

	qcacld_get_if_name $name 

	#Add to network
	wireless_add_vif "$name" "$g_qcacld_if_name"

	#Enable interface if needed
	json_select config
	json_get_var state state
	json_select ..

	if [ "$state" != "0" ] ; then
		ifconfig $g_qcacld_if_name up
#	else
#		ifconfig $g_qcacld_if_name down
	fi
}

#FRV: Setup all interfaces of a radio 
# -> pass interface names back to netifd via ubus
# -> enable them
drv_qcacld_setup() {
	g_qcacld_radio_name=$1
#	json_dump
	for_each_interface "sta ap adhoc" qcacld_setup_vif
#	wireless_set_data phy=phy0
	wireless_set_up
}

qcacld_teardown_vif() {
	local name="$1"
	local bridge

	json_get_var bridge bridge

	qcacld_get_if_name $name

	ifconfig $g_qcacld_if_name down

	if [ -n "$bridge" ]; then
		local if=$(find_config "$bridge")
		json_set_namespace tmp old
		json_init
		json_add_string name "$g_qcacld_if_name"
		json_add_boolean link-ext 1
		json_close_object
		if [ -n "$if" ]; then
			ubus call network.interface.$if remove_device "$(json_dump)"
		fi
		json_set_namespace $old
	fi
}

#FRV: Not sure what this should do.
drv_qcacld_teardown() {
	g_qcacld_radio_name=$1
	for_each_interface "sta ap adhoc" qcacld_teardown_vif
#	json_select data
#	json_get_var phy phy
#	json_select ..
#	json_dump
}

drv_qcacld_cleanup() {
	dummy=1
}

add_driver qcacld
