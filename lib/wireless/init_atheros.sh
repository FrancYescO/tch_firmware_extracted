#!/bin/sh

#Swap wifi0 and wifi1 if wifi0 is 5GHz
if [ -e /sys/class/net/wifi1 ]; then
  
  if [ "`cat /sys/class/net/wifi0/hwcaps | grep 802.11an`" != "" ]; then
    echo "$0: Swapping wifi0 and wifi1" > /dev/console

    ifconfig wifi0 down
    ifconfig wifi1 down
    ip link set dev wifi0 name old_wifi0
    ip link set dev wifi1 name wifi0
    ip link set dev old_wifi0 name wifi1
  fi
fi

#Set MAC from RIP
WIFI_MAC_2G=`uci get env.rip.wifi_mac`
WIFI_MAC_LOCAL=`uci get env.var.local_wifi_mac`

iwpriv wifi0 setHwaddr $WIFI_MAC_2G

if [ -e /sys/class/net/wifi1 ]; then
  #WIFI_MAC_LOCAL, first byte incremented by 32
  WIFI_MAC_5G="$(printf "%02X" $(((0x${WIFI_MAC_LOCAL:0:2} + 0x20) % 256)))${WIFI_MAC_LOCAL:2:16}"

  iwpriv wifi1 setHwaddr $WIFI_MAC_5G
fi

if [ -e /sys/class/net/wifi2 ]; then
  #WIFI_MAC_LOCAL, first byte incremented by 64
  WIFI_MAC_5G="$(printf "%02X" $(((0x${WIFI_MAC_LOCAL:0:2} + 0x40) % 256)))${WIFI_MAC_LOCAL:2:16}"

  iwpriv wifi2 setHwaddr $WIFI_MAC_5G
fi

#Disable FW logging
iwpriv wifi0 dl_reporten 0
[ -e /sys/class/net/wifi1 ] && iwpriv wifi1 dl_reporten 0
[ -e /sys/class/net/wifi2 ] && iwpriv wifi2 dl_reporten 0

#Set IRQ affinity                     
. /lib/update_smp_affinity.sh
enable_smp_affinity_wifi wifi0
[ -e /sys/class/net/wifi1 ] && enable_smp_affinity_wifi wifi1
[ -e /sys/class/net/wifi2 ] && enable_smp_affinity_wifi wifi2
