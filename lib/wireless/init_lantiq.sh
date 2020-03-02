#!/bin/sh

#Set mac address from RIP

#2.4GHz
if [ -e "/proc/net/mtlk/wl0" ]; then
  ifconfig wl0 hw ether `uci get env.rip.wifi_mac`
fi

#5GHz (locally admin + 8)
if [ -e "/proc/net/mtlk/wl1" ]; then 
  m=`uci get env.var.local_wifi_mac`
  ifconfig wl1 hw ether "${m:0:15}$(printf "%02X" $(((0x${m:15:16} + 0x08) % 256)))" 
fi

