#!/bin/sh

oldconfig=${1}

if [ -f $oldconfig/etc/hosts_ext ];then
  touch /etc/config/user_friendly_name
  while read line
  do
    mac=$(echo $line|cut -d "|" -f 1)
    if [ ! -z "$mac" ]; then
      hostname=$(echo $line|cut -d "|" -f 2)
      type=$(echo $line|cut -d "|" -f 3)
      uci add user_friendly_name name
      uci set user_friendly_name.@name[-1].mac=$mac
      uci set user_friendly_name.@name[-1].name=$hostname
      uci set user_friendly_name.@name[-1].type=$type
      uci commit user_friendly_name
    fi
  done < $oldconfig/etc/hosts_ext
fi

