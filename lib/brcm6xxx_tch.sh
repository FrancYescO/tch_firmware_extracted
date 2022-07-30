#!/bin/sh

brcm6xxx_tch_detect() {
	local board_name model

	if [ -e /proc/device-tree ]; then
		board_name=$(cat /proc/device-tree/compatible)
		model=$(cat /proc/device-tree/model)
	else
		local hardware=$(awk 'BEGIN{FS="[ \t:/]+"} /Hardware/ {print $2}' /proc/cpuinfo)
		model="Broadcom $hardware"
		board_name=$(echo "${hardware}" | awk '{print tolower($0)}')
		board_name="brcm,$board_name"
	fi

	[ -e "/tmp/sysinfo" ] || mkdir -p "/tmp/sysinfo"

	echo "$board_name" > /tmp/sysinfo/board_name
	echo "$model" > /tmp/sysinfo/model
}
