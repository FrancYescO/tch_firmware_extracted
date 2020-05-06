#!/bin/sh

#be sure no previous press is pending.
oldest_ongoing=$( pgrep -o -f $0 )
this_ongoing=$( pgrep -n -f $0 )
[ "$oldest_ongoing" != "$this_ongoing" ] && exit 0

. /lib/functions.sh
. /usr/share/libubox/jshn.sh

radio2G_state=$( uci_get wireless.radio_2G.state )
radio5G_state=$( uci_get wireless.radio_5G.state )
best_ch_r2G="auto"
best_ch_r5G="auto"
requested_ch_2G=""
requested_ch_5G=""
current_ch_2G=""
current_ch_5G=""
msg_2G="off"
msg_5G="off"
radio_get_rs=""

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

[ "$radio2G_state" = "1" -a "$radio5G_state" = "0" ] && {

  radio_get_rs=$( ubus call wireless.radio get )
  requested_ch_2G=$( jsonfilter -s "$radio_get_rs" -e '@.radio_2G.requested_channel' )
  current_ch_2G=$( jsonfilter -s "$radio_get_rs" -e '@.radio_2G.channel' )

  notify_leds "channel analyzing" "off"
  if [ "$requested_ch_2G" = "auto" ]; then
    ubus call wireless.radio.acs rescan '{"name":"radio_2G","act":1}'
  else
    ubus call wireless.radio.acs rescan '{"name":"radio_2G","act":0}'
  fi
  best_ch_r2G=$( ubus call wireless.radio.acs get | jsonfilter -e '@.radio_2G.scan_report' | awk -F\; '{print $3}' | awk -F/ '{print $1}' )
}
[ "$radio2G_state" = "0" -a "$radio5G_state" = "1" ] && {

  radio_get_rs=$( ubus call wireless.radio get )
  requested_ch_5G=$( jsonfilter -s "$radio_get_rs" -e '@.radio_5G.requested_channel' )
  current_ch_5G=$( jsonfilter -s "$radio_get_rs" -e '@.radio_5G.channel' )

  notify_leds "off" "channel analyzing"
  if [ "$requested_ch_5G" = "auto" ]; then
    ubus call wireless.radio.acs rescan '{"name":"radio_5G","act":1}'
  else
    ubus call wireless.radio.acs rescan '{"name":"radio_5G","act":0}'
  fi
  best_ch_r5G=$( ubus call wireless.radio.acs get | jsonfilter -e '@.radio_5G.scan_report' | awk -F\; '{print $3}' | awk -F/ '{print $1}' )
}
[ "$radio2G_state" = "1" -a "$radio5G_state" = "1" ] && {

  radio_get_rs=$( ubus call wireless.radio get )
  requested_ch_2G=$( jsonfilter -s "$radio_get_rs" -e '@.radio_2G.requested_channel' )
  current_ch_2G=$( jsonfilter -s "$radio_get_rs" -e '@.radio_2G.channel' )
  requested_ch_5G=$( jsonfilter -s "$radio_get_rs" -e '@.radio_5G.requested_channel' )
  current_ch_5G=$( jsonfilter -s "$radio_get_rs" -e '@.radio_5G.channel' )

  notify_leds "channel analyzing" "channel analyzing"
  # 1st runs in background, then wait for the 2nd to end
  if [ "$requested_ch_2G" = "auto" ]; then
    ubus call wireless.radio.acs rescan '{"name":"radio_2G","act":1}'&
  else
    ubus call wireless.radio.acs rescan '{"name":"radio_2G","act":0}'&
  fi

  if [ "$requested_ch_5G" = "auto" ]; then
    ubus call wireless.radio.acs rescan '{"name":"radio_5G","act":1}'
  else
    ubus call wireless.radio.acs rescan '{"name":"radio_5G","act":0}'
  fi

  radio_get_rs=$( ubus call wireless.radio.acs get )
  best_ch_r2G=$( jsonfilter -s "$radio_get_rs" -e '@.radio_2G.scan_report' | awk -F\; '{print $3}' | awk -F/ '{print $1}' )
  best_ch_r5G=$( jsonfilter -s "$radio_get_rs" -e '@.radio_5G.scan_report' | awk -F\; '{print $3}' | awk -F/ '{print $1}' )
}

[ "$radio2G_state" = "1" ] && {

  if [ "$requested_ch_2G" != "auto" ]
  then
    if [ "$current_ch_2G" != "$best_ch_r2G" ]
    then
      msg_2G="not best channel in use"
    else
      msg_2G="best channel in use"
    fi
  else
    if [ "$current_ch_2G" = "$best_ch_r2G" ]
    then
      msg_2G="best channel in use"
    else
      # when in auto mode, it's always the best chosen.
      uci_set wireless radio_2G channel "auto"
      uci_commit
      msg_2G="channel updated"
    fi
  fi
}

[ "$radio5G_state" = "1" ] && {

  if [ "$requested_ch_5G" != "auto" ]
  then
    if [ "$current_ch_5G" != "$best_ch_r5G" ]
    then
      msg_5G="not best channel in use"
    else
      msg_5G="best channel in use"
    fi
  else
    if [ "$current_ch_5G" = "$best_ch_r5G" ]
    then
      msg_5G="best channel in use"
    else
      # when in auto mode, it's always the best chosen.
      uci_set wireless radio_5G channel "auto"
      uci_commit
      msg_5G="channel updated"
    fi
  fi
}

record_timestamp
notify_leds "$msg_2G" "$msg_5G"


