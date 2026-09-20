#!/bin/sh
#Based on sample script from http://wiki.openwrt.org/doc/howto/hardware.button
#First check for on/off argument, otherwise default to toggling based on state of 2G radio
case $1 in
        on)
          uci -q set wireless.radio_2G.state=1
          uci -q set wireless.radio_5G.state=1
          ubus send event '{ "state":"wifi_leds_on" }'
          ;;
        off)
          uci -q set wireless.radio_2G.state=0
          uci -q set wireless.radio_5G.state=0
          ubus send event '{ "state":"wifi_leds_off" }'
          ;;
        *)
          SW=$(uci -q get wireless.radio_2G.state)
          if [ "$SW" == "1" ]; then
            uci -q set wireless.radio_2G.state=0
            uci -q set wireless.radio_5G.state=0
            ubus send event '{ "state":"wifi_leds_off" }'
          else
            uci -q set wireless.radio_2G.state=1
            uci -q set wireless.radio_5G.state=1
            ubus send event '{ "state":"wifi_leds_on" }'
          fi
          ;;
esac
uci commit wireless
/etc/init.d/hostapd reload
up=$(ps|grep /usr/sbin/hotspotd|grep -v grep)
if [ "$up" != "" ] ; then
  /etc/init.d/hotspotd reload
fi
