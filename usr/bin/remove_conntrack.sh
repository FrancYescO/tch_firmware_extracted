#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh

black_list ()  {
  local name
  config_get name "$1" name
  if [ "$name" == "Dev_Deny_Access" ] ; then
    local mac
    config_get mac "$1" src_mac
    if [ -n "$mac" ] ; then
      local callstr="ubus call hostmanager.device get '{\"mac-address\":\"$mac\" }' | grep '\"address\":'"
      local ipaddr="`eval $callstr`"
      local ip=$(echo $ipaddr | awk -F ':' '{print $2}' | tr -d '"')
      /usr/sbin/conntrack -D -s $ip > /dev/null
    else
      local callstr="ubus call network.interface.lan status | grep '\"address\":'"
      local ipaddr="`eval $callstr`"
      local ip=$(echo $ipaddr | awk -F ':' '{print $2}' | tr -d '",')
      /usr/sbin/conntrack -D -d $ip > /dev/null
    fi
  fi
}

config_load firewall
config_foreach black_list rule

