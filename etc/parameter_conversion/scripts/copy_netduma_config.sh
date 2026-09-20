#!/bin/sh

dumaos_root=/dumaos/apps
old_config="$1"

copy_config() {
	if [ -e "$old_config/$dumaos_root/$1" ]; then
		cp -r "$old_config/$dumaos_root/$1" "/$dumaos_root/$1"
	fi
}

copy_config system/com.netdumasoftware.config/data
copy_config system/com.netdumasoftware.desktop/data
copy_config system/com.netdumasoftware.deviceclass/data
copy_config system/com.netdumasoftware.devicemanager/data
copy_config system/com.netdumasoftware.neighwatch/data
copy_config system/com.netdumasoftware.networkmonitor/data
copy_config system/com.netdumasoftware.procmanager/data
copy_config system/com.netdumasoftware.rappstore/data
copy_config system/com.netdumasoftware.settings/data
copy_config system/com.netdumasoftware.systeminfo/data
copy_config usr/com.netdumasoftware.adblocker/data
copy_config usr/com.netdumasoftware.benchmark/data
copy_config usr/com.netdumasoftware.geofilter/data
copy_config usr/com.netdumasoftware.hybridvpn/data
copy_config usr/com.netdumasoftware.internetmeasurer/data
copy_config usr/com.netdumasoftware.pingheatmap/data
copy_config usr/com.netdumasoftware.qos/data
copy_config usr/com.netdumasoftware.trafficcontroller/data
copy_config usr/com.netdumasoftware.adblocker/1.DNn
copy_config usr/com.netdumasoftware.adblocker/2.DNn
copy_config usr/com.netdumasoftware.adblocker/3.DNn
copy_config usr/com.netdumasoftware.adblocker/4.DNn
