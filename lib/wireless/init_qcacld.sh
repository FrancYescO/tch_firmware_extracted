#!/bin/sh

#Change wlan0 to wl0
ifconfig wlan0 down
ip link set dev wlan0 name wl0

#Set MAC from RIP
#iwpriv wifi0 setHwaddr `uci get env.rip.wifi_mac`

