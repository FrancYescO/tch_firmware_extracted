#!/bin/sh

BOARD=`uci get env.rip.board_mnemonic`
FILE="/rom/etc/boards/$BOARD/config/etc/config/wireless"

uci commit

if [ -e "$FILE" ];
then
     cp /rom/etc/boards/$BOARD/config/etc/config/wireless /etc/config/wireless
     /rom/etc/boards/$BOARD/config/etc/uci-defaults/tch_0050-wireless
else
     cp /rom/etc/config/wireless /etc/config/wireless
     /rom/etc/uci-defaults/tch_0050-wireless
fi
/etc/init.d/hostapd reload
