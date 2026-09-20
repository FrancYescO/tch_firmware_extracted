#!/bin/sh

#be sure no previous press is pending.
oldest_ongoing=$( pgrep -o -f $0 )
this_ongoing=$( pgrep -n -f $0 )
[ "$oldest_ongoing" != "$this_ongoing" ] && exit 0

. /lib/functions.sh
. /usr/share/libubox/jshn.sh

radio2G_state=$( uci_get wireless.radio_2G.state )
radio5G_state=$( uci_get wireless.radio_5G.state )
msg_2G="off"
msg_5G="off"

record_timestamp() {
  date=`date "+%Y.%m.%d-%H:%M:%S"`
  uci set button.wifi.lastdate=${date}
  uci commit
}

notify_leds() {
  json_init;
  json_add_string action "pressed"
  json_add_object 'radioinfo'
  json_add_string 5G_state "$2"
  json_add_string 2G_state "$1"
  json_close_object

  ubus send wireless.button "$( json_dump )"
}

# both radios OFF, then turn on
[ "$radio2G_state" = "0" -a "$radio5G_state" = "0" ] && {
  uci_set wireless radio_2G state 1
  uci_set wireless radio_5G state 1
  uci_commit
  notify_leds "on" "on"
  ubus call wireless reload
}

# any radios on, then turn off
[ "$radio2G_state" = "1" -o "$radio5G_state" = "1" ] && {
  uci_set wireless radio_2G state 0
  uci_set wireless radio_5G state 0
  uci_commit
  notify_leds "off" "off"
  ubus call wireless reload
}

record_timestamp

