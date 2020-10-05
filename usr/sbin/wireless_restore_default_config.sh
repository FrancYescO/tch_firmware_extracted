#!/bin/sh

uci commit
cp /rom/etc/config/wireless /etc/config/wireless
/rom/etc/uci-defaults/tch_0050-wireless
/etc/init.d/hostapd reload
