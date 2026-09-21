#!/bin/sh

#Syntax: wireless_get_radio_type.sh <radio>
#Note: this script can only handle the combinations that are on the current platfor

RADIO=$1

#Default
RADIO_TYPE=broadcom

#Detect Atheros
if [ -e "/proc/athversion" ] ; then
  RADIO_TYPE=atheros
fi

#Detect Quantenna
if [ "$RADIO" = "radio_5G" ] && [ -e "/qtn/qtn-linux.lzma" ] ; then
  RADIO_TYPE=quantenna
fi

#NL80211 (qcacld and lantiq)
DUMMY=`iw dev 2> /dev/null`
if [ "$?" == "0" ] ; then
  FIRST_IFACE=`iw dev | grep Interface | cut -d ' '  -f 2 | head -n 1`

  #QCACLD
  DUMMY=`iwpriv $FIRST_IFACE version 2> /dev/null | grep QCA`
  if [ "$?" == "0" ] ; then
    RADIO_TYPE=qcacld
  fi
 
  #Lantiq
  if [ "$RADIO" = "radio_2G" ] && [ -e "/proc/net/mtlk/wl0" ] ; then
    RADIO_TYPE=lantiq
  fi 
  if [ "$RADIO" = "radio_5G" ] && [ -e "/proc/net/mtlk/wl1" ] ; then
    RADIO_TYPE=lantiq
  fi 
  
fi

echo "$RADIO_TYPE"
