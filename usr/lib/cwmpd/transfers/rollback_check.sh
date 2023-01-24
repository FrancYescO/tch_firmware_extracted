#!/bin/sh

UPGRADE_FROM_OLDER=""

OLD_CONFIG=$1
if [ -z $OLD_CONFIG ]; then
	# upgrade from legacy
	echo "Upgrade from legacy"
	UPGRADE_FROM_OLDER="Legacy"
else
	if [ -z $(uci -c $OLD_CONFIG/etc/config get cwmp_transfer.@rollback_info[0].rollback_to 2>/dev/null) ]; then
		# upgrade from homeware without proper rollback
		echo "Upgrade from older Homeware"
		UPGRADE_FROM_OLDER="Homeware"
	fi
fi

if [ ! -z "$UPGRADE_FROM_OLDER" ]; then
	uci show cwmp_transfer.@rollback_info[0] >/dev/null 2>/dev/null
	if [ $? -ne 0 ]; then
		echo "Creating rollback_info section"
		uci add cwmp_transfer rollback_info
	fi
	BANK=$(cat /proc/banktable/notbooted 2>/dev/null)
	if [ ! -z $BANK ]; then
		 echo "setting rollback_to to $BANK"
		uci set cwmp_transfer.@rollback_info[0].rollback_to=$BANK
		uci set cwmp_transfer.@rollback_info[0].started=0
		uci set cwmp_transfer.@rollback_info[0].guessed_from=$UPGRADE_FROM_OLDER
		uci commit
	fi
fi
