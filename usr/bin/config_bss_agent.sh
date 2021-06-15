#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh

if [ $# -eq 0 ]
  then
    echo "Specify the interface to be added! "
    exit 1
fi

SET_ON=1

set_bss_on()
{
  config_get bss_state ${1} state

  if echo "${2}" | grep -q "\<${1}\>" ; then
    if [ $bss_state != 1 ] ; then
      transformer-cli set uci.wireless.wifi-iface.@${1}.state 1
      SET_ON=$((SET_ON + 1))
    fi
  fi
}

let intfname=eth
intfname=$1
echo "Interface to be added in multiap is $intfname"

echo "Add the Ethernet interface $intfname to multiap"
al_interfaces=`uci get multiap.al_entity.interfaces`
eval "echo \$al_interfaces | grep \"$intfname\" | grep -v \"grep\""
if [ "$?" -eq "1" ]; then
   al_interfaces=`printf "$intfname,$al_interfaces"`
   uci set multiap.al_entity.interfaces=$al_interfaces
   uci commit multiap
fi

##Turn on bss state
config_load wireless
map_agent_bsslist=`uci get multiap.agent.bss_list`
config_foreach set_bss_on wifi-iface $map_agent_bsslist
if [ "$SET_ON" != 0 ] ; then
  transformer-cli apply
fi

#sleep for a while
sleep 10

echo "Start the agent"
/etc/init.d/multiap_agent start
