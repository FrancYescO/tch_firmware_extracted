#!/bin/sh

#be sure no previous press is pending.
oldest_ongoing=$( pgrep -o -f $0 )
this_ongoing=$( pgrep -n -f $0 )
[ "$oldest_ongoing" != "$this_ongoing" ] && exit 0

. /lib/functions.sh
. /usr/share/libubox/jshn.sh

notify_leds() {

  json_init;
  json_add_string action "pressed"
  json_add_string lineinfo "$1"

  ubus send line.button "$( json_dump )"
}

record_timestamp() {
  date=`date "+%Y.%m.%d-%H:%M:%S"`
  uci set button.line.lastdate=${date}
  uci commit
}

record_timestamp
target=$( uci_get system.config.net_btn_target )
[ "$target" = "" ] && target="8.8.4.4"

ping -q -c3 -W2 $target > /dev/null
if [ $? -eq 0 ]
then
  notify_leds "ping OK"
else
  notify_leds "ping KO"
fi

