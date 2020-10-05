#!/bin/sh  /etc/rc.common

. $IPKG_INSTROOT/lib/functions.sh

USE_PROCD=1
LB="[load_balancer]: "
LOAD_BALANCER_BIN=/usr/bin/load_balancer
CONF_FILE="/etc/config/mwan"

start_service()
{
  config_load mwan
  config_get_bool enabled "global" enabled 0

  if [ "$enabled" = 1 ] ; then
    logger -t $LB "load_balancer start"
    procd_open_instance
    procd_set_param command $LOAD_BALANCER_BIN
    procd_set_param file $CONF_FILE
    procd_set_param respawn
    procd_set_param reload_signal SIGHUP
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
  else
    logger -t $LB "load_balancer not enabled"
  fi
}

stop_service()
{
  logger -t $LB "load_balancer stop"
}
