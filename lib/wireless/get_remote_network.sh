#!/bin/sh

. /usr/share/libubox/jshn.sh

if [ "$1" != "" ] ; then
  ipaddr=$1
else

  #1) Get IP from remote config
  UBUS_OUTPUT=$(eval "ubus call wireless.radio.remote get")
  json_load "$UBUS_OUTPUT"
  json_get_keys radios

  #Currently support only one radio
  json_select $radios
  json_get_var ipaddr ipaddr

  if [ "$ipaddr" = "" ] ; then
    echo -n unknown
    exit
  fi
fi

#2) Find interface
ifname=`ip route get $ipaddr | cut -d ' ' -f 3`

#3) Search network
UBUS_OUTPUT=$(eval "ubus call network.interface dump")
json_load "$UBUS_OUTPUT"

json_get_keys interfaces interface

json_select interface

for interface in $interfaces ; do
  json_select $interface

  json_get_var interface_name interface
  json_get_var l3_device l3_device

  if [ "$ifname" = "$l3_device" ] ; then
    echo -n $interface_name
    exit
  fi

  json_select ..

done

echo -n unknown
