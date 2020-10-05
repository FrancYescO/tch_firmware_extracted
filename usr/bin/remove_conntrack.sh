#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh


black_list ()  {
  if ( echo $1 | grep -q "black_list_rule" ) ; then
    local mac
    config_get mac "$1" src_mac
    local callstr="ubus call hostmanager.device get '{\"mac-address\":\"$mac\" }' | grep '\"address\":'"
    local ipaddr="`eval $callstr`"
    local ip=$(echo $ipaddr | awk -F ':' '{print $2}' | tr -d '"')
    /usr/sbin/conntrack -D -s $ip > /dev/null
  fi

  if ( echo $1 | grep -q "bl_restricted_rule") ; then
    local callstr="ubus call network.interface.lan status | grep '\"address\":'"
    local ipaddr="`eval $callstr`"
    local ip=$(echo $ipaddr | awk -F ':' '{print $2}' | tr -d '",')
    /usr/sbin/conntrack -D -d $ip > /dev/null
  fi
}

config_load firewall
config_foreach black_list rule

