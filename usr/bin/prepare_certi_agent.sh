#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh

SET_OFF=1

set_bss_off()
{
  config_get bss_state ${1} state

  if [ $bss_state != 0 ] ; then
    transformer-cli set uci.wireless.wifi-iface.@${1}.state 0
    SET_OFF=$((SET_OFF + 1))
  fi
}

##To make 1905 stack not operational
echo "Stop the agent"
/etc/init.d/multiap_agent stop

## Turn off BSS(s)
echo "Turning OFF BSS"
config_load wireless
config_foreach set_bss_off wifi-iface
if [ "$SET_OFF" != 0 ] ; then
  transformer-cli apply
fi

#check for eth interfaces and turn down all except where agent is connected to CTD
echo "Turn down all ETH interfaces except where it is connected to CTD"
lan_interfaces=`uci get network.lan.ifname`

for i in ${lan_interfaces}
do
  carrier_bit=$(cat /sys/class/net/$i/carrier)
  if [ $carrier_bit != 1 ]
  then
    echo "physically not connected, so turning down the interface $i"
    ifconfig $i down
  fi
done

## Set agent.enabled to 1
echo "Setting agent.enabled to 1"
enabled=`uci get multiap.agent.enabled`
if [ $enabled != 1 ] ; then
  uci set multiap.agent.enabled=1
  uci commit
fi

# clear arp table (To Do - Find a way to flush ARP cache instead of restarting network)
