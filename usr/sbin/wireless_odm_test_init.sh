#!/bin/sh

DUMMY=`uci get wireless.radio_5G &> /dev/null`
if [ "$?" == "0" ] ; then
  IS_DUAL_BAND=1
fi

#Set fixed channel
uci set wireless.radio_2G.channel=1
if [ "$IS_DUAL_BAND" == "1" ] ; then
  CHAN_5G=`wl -i wl1 chanspecs|head -n 1|cut -d ' ' -f 1`
  uci set wireless.radio_5G.channel=$CHAN_5G
fi

#Disable TX power adjust
uci set wireless.radio_2G.tx_power_adjust=0
if [ "$IS_DUAL_BAND" == "1" ] ; then
  uci set wireless.radio_5G.tx_power_adjust=0
fi

#Set security mode to none
disable_security()
{
  DUMMY=`uci get wireless.$1 &> /dev/null`
  if [ "$?" == "0" ] ; then
    uci set wireless.$1.security_mode=none
  fi
}

for AP in ap0 ap1 ap2 ap3 ap4 ap5 ap6 ap7 ; do
  disable_security $AP
done

#Disable MBSS interfaces
disable_interface()
{
  DUMMY=`uci get wireless.$1 &> /dev/null`
  if [ "$?" == "0" ] ; then
    uci set wireless.$1.state=0
  fi
}

for IF in wl0_1 wl0_2 wl0_3 wl1_1 wl1_2 wl1_3 ; do
  disable_interface $IF
done

uci commit wireless
/etc/init.d/hostapd reload

