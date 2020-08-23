#!/bin/sh

#be sure no previous press is pending.
oldest_ongoing=$( pgrep -o -f $0 )
this_ongoing=$( pgrep -n -f $0 )
[ "$oldest_ongoing" != "$this_ongoing" ] && exit 0

. /lib/functions.sh
. /usr/share/libubox/jshn.sh

local wps_enabled=0

record_timestamp() {
  date=`date "+%Y.%m.%d-%H:%M:%S"`
  uci set button.wps.lastdate=${date}
  uci commit
}

notify_leds() {

  json_init;
  json_add_string action "pressed"
  json_add_string wpsinfo "$1"
  json_close_object

  ubus send wps.button "$( json_dump )"
}

radio2G_state=$( uci_get wireless.radio_2G.state )
radio5G_state=$( uci_get wireless.radio_5G.state )

# both radios OFF, then turn on
[ "$radio2G_state" = "0" -a "$radio5G_state" = "0" ] && {
  notify_leds "WPS activate both radios"
  uci_set wireless radio_2G state 1
  uci_set wireless radio_5G state 1
  uci_commit
  notify_leds "WPS activate both radios"
  ubus call wireless reload
  exit 0
}

#if any radio is On, trigger pbc
[ "$radio2G_state" = "1" -o "$radio5G_state" = "1" ] && ubus call wireless wps_button

wifi_ap_check() {
  config_get iface "$1" iface ""
  if [ "$iface" = "$2" ]; then
    config_get wps_state "$1" wps_state ""
    if [ "$wps_state" = "1" ]; then
      wps_enabled=1;
    fi
  fi
}

wifi_interface_check() {
  config_get ssid "$1" ssid ""
  case "$ssid" in
    FASTWEB*)
      config_foreach wifi_ap_check wifi-ap $1
    ;;
  esac
}
config_load wireless
config_foreach wifi_interface_check wifi-iface

if [ "$wps_enabled" = 0 ]; then
  uci set ledfw.wps.status="wps_off"
  uci set ledfw.wps.color="red-solid"
  uci commit
fi

record_timestamp

