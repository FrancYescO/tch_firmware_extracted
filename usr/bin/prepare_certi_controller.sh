#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/usr/bin/map_common_reset_credentials.sh

SET_OFF=0

set_bss_off()
{
  config_get bss_state ${1} state

  if [ $bss_state != 0 ] ; then
    transformer-cli set uci.wireless.wifi-iface.@${1}.state 0
    SET_OFF=$((SET_OFF + 1))
  fi
}

## Stop controller process to make 1905 stack not operational
echo "Stopping multiap_controller"
/etc/init.d/multiap_controller stop

## Reset controller credentials
echo "Resetting multiap controller_credentials"
set_FH_credentials
set_BH_credentials

## Turn off BSS(s)
echo "Turning OFF BSS"
config_load wireless
config_foreach set_bss_off wifi-iface
if [ "$SET_OFF" != 0 ] ; then
  transformer-cli apply
fi

## Set controller.enabled to 1
echo "Setting controller.enabled to 1"
enabled=`uci get multiap.controller.enabled`
if [ $enabled != 1 ] ; then
  uci set multiap.controller.enabled=1
  uci commit
fi

## Set link_metric_query_interval to 0
echo "Setting link_metric_query_interval to 0"
link_metric_query_interval=`uci get multiap.controller.link_metric_query_interval`
if [ $link_metric_query_interval != 0 ] ; then
  uci set multiap.controller.link_metric_query_interval=0
  uci commit
fi

## Set metrics_report_interval to 255
echo "Setting metrics_report_interval to 255"
metrics_report_interval=`uci get multiap.controller_policy_config.metrics_report_interval`
if [ $metrics_report_interval != 255 ] ; then
  uci set multiap.controller_policy_config.metrics_report_interval=255
  uci commit
fi

## Flush ARP table (To Do - Find a way to flush ARP cache instead of restarting network)

## Start controller and agent process
echo "Starting multiap_controller"
/etc/init.d/multiap_controller start
