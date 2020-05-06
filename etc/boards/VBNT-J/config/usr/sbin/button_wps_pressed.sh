#!/bin/sh

#be sure no previous press is pending.
oldest_ongoing=$( pgrep -o -f $0 )
this_ongoing=$( pgrep -n -f $0 )
[ "$oldest_ongoing" != "$this_ongoing" ] && exit 0

. /lib/functions.sh
. /usr/share/libubox/jshn.sh

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


record_timestamp

