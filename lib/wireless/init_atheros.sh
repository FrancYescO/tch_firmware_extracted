#!/bin/sh

#Swap wifi0 and wifi1 if wifi0 is 5GHz
if [ -e "/sys/class/net/wifi1" ] ; then
  
  if [ "`cat /sys/class/net/wifi0/hwcaps | grep 802.11an`" != "" ] ; then
    echo "$0: Swapping wifi0 and wifi1" > /dev/console

    ifconfig wifi0 down
    ifconfig wifi1 down
    ip link set dev wifi0 name old_wifi0
    ip link set dev wifi1 name wifi0
    ip link set dev old_wifi0 name wifi1
  fi
fi

#Set MAC from RIP
iwpriv wifi0 setHwaddr `uci get env.rip.wifi_mac`

