#!/bin/sh
#
# Copyright (C) 2016 ADB Italia
#
# Configuration Handlers - helper functions to update TR-181 Device data model
#

. /etc/ah/helper_status.sh

cm181_dev_info()
{
	local v

	for p in SerialNumber HardwareVersion ProductClass Manufacturer ManufacturerOUI ModelName; do
		v=$(cmclient GETV Device.X_ADB_FactoryData.${p})
		[ ${#v} -ne 0 ] && cmclient SET Device.DeviceInfo.${p} "$v"
	done
}

cm181_eth_link()
{
	local obj status

	obj=$(cmclient GETO Device.Ethernet.Link)
	for obj in $obj; do
		help_get_status status "$obj"
		cmclient SET ${obj}.Status "$status"
	done
}

cm181_ip_interface()
{
	local obj status

	obj=$(cmclient GETO Device.IP.Interface)
	for obj in $obj; do
		help_get_status status "$obj"
		cmclient SET ${obj}.Status "$status"
	done
}

cm181_man_server()
{
	cmclient SET Device.ManagementServer.[EnableCWMP=true].EnableCWMP true
}

help_cm181_init()
{
	cm181_dev_info
}

help_cm181_update()
{
	cm181_eth_link
	cm181_ip_interface
	cm181_man_server
}
